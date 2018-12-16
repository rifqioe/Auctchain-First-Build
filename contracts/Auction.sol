pragma solidity ^0.4.24;

contract AuctchainHouse {
    
    struct Bid {
        address bidder;
        uint amount;
        uint timestamp;
    }
    
    struct PersonInfo{
        string  name;
        string  email;
        string  contact;
        bool status;
    }
    
    enum AuctionStatus {Pending, Active, Inactive}
    
    struct Auction {
        // Location and ownership information of the item for sale
        address seller;
        
        // Auction metadata
        string title;
        string description;
        string link;
        uint blockNumberOfDeadline;
        AuctionStatus status;
        
        // Pricing
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 currentBid;
        
        Bid[] bids;
    }
    
    Auction[] public auctions; // All created auctions
    
    mapping(address => PersonInfo) registeredUser;
    mapping(address => uint[]) public auctionsRunByUser; // Pointer to auctions index for auctions run by this user
    mapping(address => uint[]) public auctionsBidOnByUser; // Pointer to auctions index for auctions this user has bid on
    mapping(address => uint) refunds;
    
    // Events
    event AccountRegistered(string name, string email, string contact);
    event AuctionCreated(uint id, string title, uint256 startingPrice);
    event BidPlaced(uint auctionId, address bidder, uint256 amount);
    event AuctionEndedWithWinner(uint auctionId, address winningBidder, uint256 amount);
    event AuctionEndedWithoutWinner(uint auctionId, uint256 topBid, uint256 reservePrice);
    
    function register(
        string _name,
        string _email,
        string _contact) public {
            
        registeredUser[msg.sender] = PersonInfo(_name,_email,_contact,true);
        emit AccountRegistered(_name, _email, _contact);
    }

    function isRegistered(address addr) public view returns (bool) {
        return registeredUser[addr].status;
    }

    function getRegisteredData() public view returns (string, string, string){
        return (
            registeredUser[msg.sender].name,
            registeredUser[msg.sender].email,
            registeredUser[msg.sender].contact);
    }
    
    function createAuction(
        string _title,
        string _description,
        string _link,
        uint _deadline,
        uint256 _startingPrice,
        uint256 _reservePrice) public returns (uint auctionId) {
        
        require(registeredUser[msg.sender].status);
    
        auctionId = auctions.length++;
        Auction storage a = auctions[auctionId];
        
        a.seller = msg.sender;
        a.title = _title;
        a.description = _description;
        a.link = _link;
        a.blockNumberOfDeadline = _deadline;
        a.status = AuctionStatus.Active;
        a.startingPrice = _startingPrice;
        a.reservePrice = _reservePrice;
        a.currentBid = _startingPrice;
        
        auctionsRunByUser[a.seller].push(auctionId);
        
        emit AuctionCreated(auctionId, a.title, a.startingPrice);
    }
    
    function getAuction(uint idx) public view returns (
        address,
        string,
        string,
        string,
        uint,
        uint256,
        uint256,
        uint) {
        
        Auction storage a = auctions[idx];
        require(a.seller != address(0));
        
        return (
            a.seller,
            a.title,
            a.description,
            a.link,
            a.blockNumberOfDeadline,
            a.startingPrice,
            a.reservePrice,
            a.bids.length);
    }
    
    function getAuctionCount() public view returns (uint) {
        return auctions.length;
    }
    
    function getStatus(uint idx) public view returns (uint) {
        Auction storage a = auctions[idx];
        return uint(a.status);
    }

    function getAuctionsCountForUser(address addr) public view returns (uint) {
        return auctionsRunByUser[addr].length;
    }

    function getAuctionIdForUserAndIdx(address addr, uint idx) public view returns (uint) {
        return auctionsRunByUser[addr][idx];
    }
    
    function getBidCountForAuction(uint auctionId) public view returns (uint) {
        Auction storage a = auctions[auctionId];
        return a.bids.length;
    }
    
    // First version
    function getBidForAuctionByIdx(uint auctionId, uint idx) public view returns (address bidder, uint256 amount, uint timestamp) {
        Auction storage a = auctions[auctionId];
        require(idx <= a.bids.length - 1);

        Bid storage b = a.bids[idx];
        return (b.bidder, b.amount, b.timestamp);
    }
    
    function placeBid(uint auctionId) public payable returns (bool success) {
        require(registeredUser[msg.sender].status);
        
        uint256 amount = msg.value;
        Auction storage a = auctions[auctionId];

        require(a.currentBid < amount);

        uint bidIdx = a.bids.length++;
        Bid storage b = a.bids[bidIdx];
        b.bidder = msg.sender;
        b.amount = amount;
        b.timestamp = now;
        a.currentBid = amount;

        auctionsBidOnByUser[b.bidder].push(auctionId);

        // Log refunds for the previous bidder
        if (bidIdx > 0) {
            Bid storage previousBid = a.bids[bidIdx - 1];
            refunds[previousBid.bidder] += previousBid.amount;
        }

        emit BidPlaced(auctionId, b.bidder, b.amount);
        return true;
    }
    
    function getRefundValue() public view returns (uint) {
        return refunds[msg.sender];
    }

    function withdrawRefund() public payable returns (bool) {
        uint refund = refunds[msg.sender];
        refunds[msg.sender] = 0;
        if (msg.sender.send(refund)){
            return true;
        } else {
            refunds[msg.sender] = refund;
            return false;
        }
            
    }
    
    function endAuction(uint auctionId) public payable returns (bool success) {
        Auction storage a = auctions[auctionId];

        // Make sure auction hasn't already been ended
        require(a.status == AuctionStatus.Active);
        
        // require(block.number >= a.blockNumberOfDeadline); // Still learn more about this

        // No bids, make the auction inactive
        if (a.bids.length == 0) {
            a.status = AuctionStatus.Inactive;
            return true;
        }

        Bid storage topBid = a.bids[a.bids.length - 1];

        // If the auction hit its reserve price
        if (a.currentBid >= a.reservePrice) {
            a.seller.transfer(topBid.amount);
            emit AuctionEndedWithWinner(auctionId, topBid.bidder, a.currentBid);
        }
        
        a.status = AuctionStatus.Inactive;
        return true;
        
    }
    
    // function getAuctionBidList(){
        
    // }
}