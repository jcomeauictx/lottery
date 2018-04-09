pragma solidity ^0.4.19;

/* This lottery compares the low byte of sender's address with that of the
 * mined block. All matching entries for that block split the jackpot.

 * This method avoids two common attacks: by rewarding all winning entries,
 * no miner is incentivized to reorder entries. And by using the block hash,
 * which cannot be known at time of mining, there is no way to guess the
 * winning address and create one to match.
 *
 * This comes, however, with extra complexity and thus gas cost for an entry,
 * and the most cost is borne by the first bidder in a new block.
 */

contract Lottery {
    // note: uint is alias for uint256
    // constants
    uint public lastLottery;  // self-destruct after this one
    // initialization
    uint public rakePercent;  // percentage to skim for owner
    uint public ticketPrice;  // amount of wei to buy a ticket
    // state variables
    uint public lotteriesCompleted;  // lotteries finished, 0-based
    uint public lastTicketTime;  // unix timestamp of last ticket purchase
    uint public jackpot;  // prize at this moment
    uint public currentBlock;  // block for which entries are being tallied
    address[] public entries;  // addresses of ticket purchasers for this block
    address public owner;  // address of lottery contract publisher
    // for debugging only, move these to checkIfWon for release
    bytes32 public lastBlockhash;  // previous block's hash

    // events
    event LogMessage(string message);

    // constructor
    /* turns out if you don't pass arguments to constructor, it doesn't
     * fail but the variables are uninitialized, which in the case of uint
     * means they are 0. this is fine for `rake` but the ticket needs to
     * cost something.
     * lastLottery is set to the "terminate" argument, it must be nonzero
     * to have any effect, otherwise the contract ends at the default value.
     */
    function Lottery(uint rake, uint price, uint terminate) public {
        emit LogMessage("registering new lottery");
        owner = msg.sender;
        rakePercent = rake;  // specified in percent
        ticketPrice = price > 0 ? price : .005 ether;  // specified in wei
        // contract is deleted after lastLottery complete
        lastLottery = terminate > 0 ? terminate : 1;
        emit LogMessage("lottery registered");
    }

    // default, for anyone who just wants to send us money
    function () public payable {
        emit LogMessage("you've got money!");
    }

    // let owner withdraw all non-lottery funds
    function withdraw() public {
        uint available;
        if (msg.sender == owner) {
            available = address(this).balance - jackpot;
            if (available > 0) owner.transfer(available);
        }
    }

    // allow checking length of array from outside
    function totalEntries() public view returns (uint) {
        return entries.length;
    }

    // check for winner and set state
    /* another, possibly better if the lottery becomes really popular, would
     * be to store ticket purchases and block numbers in one or more mappings,
     * and let each participant check if they won and withdraw winnings.
     */

    // helper function
    function compareFinalByte(address entry, bytes32 hash)
            public pure returns (bool) {
        return uint(entry) & 0xff == uint(hash[31]);
    }

    function checkIfWon() private {
        uint winners = 0;
        uint payout;
        bool sent;
        require(block.number >= currentBlock);
        if (block.number > currentBlock) {
            lastBlockhash = blockhash(currentBlock);
            /* two loops through the entries:
             * first to count winners for dividing the pot,
             * the second to pay each winner.

             * don't check for winners if the pot has fewer than 10 entries,
             * or if lastBlockhash is 0, which means we couldn't get the
             * hash because we're over 256 blocks after the last was mined.
             */
            if (lastBlockhash > 0 && entries.length >= 10) {
                for (uint index = 0; index < entries.length; index++) {
                    address entry = entries[index];
                    if (compareFinalByte(entry, lastBlockhash)) {
                        winners++;
                    }
                }
            }
            if (winners > 0) {
                payout = jackpot / winners;
                for (index = 0; index < entries.length; index++) {
                    entry = entries[index];
                    if (compareFinalByte(entry, lastBlockhash)) {
                        /* attempt to send payout to each winner. any failed
                         * payments remain in the pot for next lottery.
                         */
                        sent = entry.send(payout);
                        if (sent) jackpot -= payout;
                    }
                }
                delete(entries);  // empties the list
                lotteriesCompleted++;
            }
            currentBlock = block.number;
        }
    }

    // lets customer buy a ticket
    function ticket() public payable {
        // we gladly accept donations over or under ticket purchase price
        if (lotteriesCompleted == lastLottery) {
            emit LogMessage("destroying contract");
            /* last lottery was ended either with ticket purchase, in which
             * case there will be one entry in the list, or by some as-yet-
             * nonexistent method which would not make a ticket entry.
             * 
             * if the former, reward the buyer who closed out the last lottery.
             */
            require(entries.length < 2);
            if (entries.length == 1) {
                emit LogMessage("final payout to ender of last lottery");
                selfdestruct(entries[0]);
            } else {
                emit LogMessage("final payout to lottery owner");
                selfdestruct(owner);
            }
        }
        checkIfWon();
        if (msg.value >= ticketPrice) {
            jackpot += ticketPrice;
            entries.push(msg.sender);
            lastTicketTime = now;
        }
    }
}
/* vim: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */
