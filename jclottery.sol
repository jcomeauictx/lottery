pragma solidity ^0.4.21;

/* This lottery compares the low byte of sender's address with that of the
 * mined block. All matching entries for that block split the jackpot.

 * This method avoids two common attacks: by rewarding all winning entries,
 * no miner is incentivized to reorder entries. And by using the block hash,
 * which cannot be known at time of mining, there is no way to guess the
 * winning address and create one to match.
 *
 * This comes, however, with extra complexity and thus gas cost for an entry.
 */

contract Lottery {
    // note: uint is alias for uint256
    // structs
    struct Tickets {
        address ticket;
        uint count;
    }

    struct Numbers {
        Tickets[] tickets;
        uint count;
    }

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
    Numbers[256] public entries;
    uint public totalEntries;
    address public owner;  // address of lottery contract publisher
    address public lastBuyer; // last ticket purchaser
    bytes32 public lastBlockhash;  // previous block's hash
    uint public lastPurchaseCount;  // number of tickets in last purchase

    // events
    event LogMessage(string message);

    // constructor
    /* turns out if you don't pass arguments to constructor, it doesn't
     * fail but the variables are uninitialized, which in the case of uint
     * means they are 0. this is fine for `rake` but the ticket needs to
     * cost something.
     * lastLottery is set to the "terminate" argument, it must be nonzero
     * to have any effect.
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

    // check for winner and set state
    function checkIfWon() private {
        Numbers storage winners;
        Tickets storage winner;
        uint payout;
        bool sent;
        uint funds;
        if (block.number > currentBlock) {
            lastBlockhash = block.blockhash(currentBlock);
            /* don't check for winners if the pot has fewer than 10 entries,
             * or if lastBlockhash is 0, which means we couldn't get the
             * hash because we're over 256 blocks after the last was mined.
             */
            if (lastBlockhash != 0 && totalEntries >= 10) {
                winners = entries[uint(lastBlockhash[31])];
            }
            if (winners.count > 0) {
                payout = jackpot / winners.count;
                for (uint index = 0; index < winners.tickets.length; index++) {
                    winner = winners.tickets[index];            
                    funds = payout * winner.count;
                    sent = winner.ticket.send(funds);
                    if (sent) jackpot -= funds;
                }
                delete(entries);  // empties the list
                lastPurchaseCount = 0;
                lotteriesCompleted++;
            }
            currentBlock = block.number;
        }
    }

    // lets customer buy a ticket
    function ticket() public payable {
        // we gladly accept donations over or under ticket purchase price
        uint tickets = 0;
        uint number = uint(msg.sender) & 0xff;
        if (lastLottery > 0 && lotteriesCompleted == lastLottery) {
            emit LogMessage("destroying contract");
            /* last lottery was ended either with ticket purchase, in which
             * case there will be a nonzero count, or by calling
             * ticket() without sufficient value.
             * 
             * if the former, reward the buyer who closed out the last lottery.
             */
            if (totalEntries > 0) {
                emit LogMessage("final payout to ender of last lottery");
                selfdestruct(lastBuyer);
            } else {
                emit LogMessage("final payout to lottery owner");
                selfdestruct(owner);
            }
        }
        checkIfWon();
        if (msg.value >= ticketPrice) {
            lastBuyer = msg.sender;
            emit LogMessage("selling tickets");
            tickets = msg.value / ticketPrice;
            jackpot += ticketPrice * tickets;
            entries[number].tickets.push(Tickets(lastBuyer, tickets));
            entries[number].count += tickets;
            totalEntries += tickets;
            lastPurchaseCount = tickets;
            lastTicketTime = now;
        }
    }
}
/* vim: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */
