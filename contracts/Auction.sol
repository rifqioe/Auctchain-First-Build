pragma solidity ^0.4.24;

contract AuctchainHouse {
    
    // Enum for auction status
    enum AuctionStatus {Pending, Active, Inactive}
    
    // Struct for Bid metadata
    struct Bid {
        address bidder;
        uint amount;
        uint timestamp;
    }
    
    // Struct for PersonInfo metadata
    struct PersonInfo{
        string  name;
        string  email;
        string  contact;
        bool status;
    }
    
    // Struct for Auction metadata
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
        uint256 currentBid;
        
        // Bid data
        Bid[] bids;
    }
    
    Auction[] public auctions; // All created auctions
    
    mapping(address => PersonInfo) registeredUser;
    mapping(address => uint[]) public auctionsRunByUser; // Pointer to auctions index for auctions run
    mapping(address => uint[]) public auctionsBidOnByUser; // Pointer to auctions index for auctions has bid on
    mapping(address => uint) refunds;
    mapping(address => Bid) public History;
    
    // All Events
    event AccountRegistered(string name, string email, string contact);
    event AuctionCreated(uint id, string title, uint256 startingPrice);
    event BidPlaced(uint auctionId, address bidder, uint256 amount);
    event AuctionEndedWithWinner(uint auctionId, address winningBidder, uint256 amount);
    event AuctionEndedWithoutWinner(uint auctionId, uint256 topBid, uint256 reservePrice);
    
    /* User Register Section ----------------------------------- */
    // Function for user register
    function register(
        string _name,
        string _email,
        string _contact) public {
            
        registeredUser[msg.sender] = PersonInfo(_name,_email,_contact,true);
        emit AccountRegistered(_name, _email, _contact);
    }
    
    // Function for check that user are registered
    function isRegistered(address addr) public view returns (bool) {
        return registeredUser[addr].status;
    }

    function getRegisteredData() public view returns (string, string, string){
        return (
            registeredUser[msg.sender].name,
            registeredUser[msg.sender].email,
            registeredUser[msg.sender].contact);
    }
    /* End User Register Section ------------------------------- */
    
    /* Auction Section ----------------------------------------- */
    function createAuction(
        string _title,
        string _description,
        string _link,
        uint _deadline,
        uint256 _startingPrice) public returns (uint auctionId) {
        
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
        uint) {
        
        Auction storage a = auctions[idx];
        require(a.seller != msg.sender);
        
        return (
            a.seller,
            a.title,
            a.description,
            a.link,
            a.blockNumberOfDeadline,
            a.startingPrice,
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
    
    function getBidForAuctionByIdx(uint auctionId, uint idx) public view 
        returns (address bidder, uint256 amount, uint timestamp) {
        Auction storage a = auctions[auctionId];
        require(idx <= a.bids.length - 1);

        Bid storage b = a.bids[idx];
        return (b.bidder, b.amount, b.timestamp);
    }
    
    function placeBid(uint auctionId) public payable returns (bool success) {
        require(registeredUser[msg.sender].status);
        
        Auction storage a = auctions[auctionId];
        require(a.seller != msg.sender);
        
        uint256 amount = msg.value;
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

    function withdrawRefund() public returns (bool) {
        uint refund = refunds[msg.sender];
        refunds[msg.sender] = 0;
        msg.sender.transfer(refund);
    }
    
    function endAuction(uint auctionId) public returns (bool success) {
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
        if(a.currentBid > a.startingPrice) {}
            a.seller.transfer(topBid.amount);
            emit AuctionEndedWithWinner(auctionId, topBid.bidder, a.currentBid);
        }
        
        a.status = AuctionStatus.Inactive;
        return true;
        
    }
    /* End Auction Section ------------------------------------- */
    
    /* History Section ----------------------------------------- */
    /* End History Section ------------------------------------- */
}