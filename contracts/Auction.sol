pragma solidity ^ 0.4 .24;

contract AuctchainHouse {

    // Enum for auction status
    enum AuctionStatus {
        Pending,
        Active,
        Inactive
    }

    // Struct for Bid metadata
    struct Bid {
        address bidder;
        uint amount;
        uint timestamp;
    }

    // Struct for PersonInfo metadata
    struct PersonInfo {
        string name;
        string email;
        string contact;
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

        registeredUser[msg.sender] = PersonInfo(_name, _email, _contact, true);
        emit AccountRegistered(_name, _email, _contact);
    }

    // Function for check that user are registered
    function isRegistered(address addr) public view returns(bool) {
        return registeredUser[addr].status;
    }

    function getRegisteredData(address addr) public view returns(string, string, string) {
        return (
            registeredUser[addr].name,
            registeredUser[addr].email,
            registeredUser[addr].contact);
    }
    /* End User Register Section ------------------------------- */

    /* Auction Section ----------------------------------------- */
    function createAuction(
        string _title,
        string _description,
        string _link,
        uint _deadline,
        uint256 _startingPrice) public returns(uint auctionId) {

        require(registeredUser[msg.sender].status);

        auctionId = auctions.length++;
        Auction a = auctions[auctionId];

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

    function getAuction(uint idx) public view returns(
        address,
        string,
        string,
        string,
        uint,
        uint256,
        uint) {

        Auction a = auctions[idx];

        return (
            a.seller,
            a.title,
            a.description,
            a.link,
            a.blockNumberOfDeadline,
            a.startingPrice,
            a.bids.length);
    }

    function getAuctionCount() public view returns(uint) {
        return auctions.length;
    }

    function getStatus(uint idx) public view returns(uint) {
        Auction a = auctions[idx];
        return uint(a.status);
    }

    function getAuctionsCountForUser(address addr) public view returns(uint) {
        return auctionsRunByUser[addr].length;
    }

    function getAuctionIdForUserAndIdx(address addr, uint idx) public view returns(uint) {
        return auctionsRunByUser[addr][idx];
    }

    function getBidCountForAuction(uint auctionId) public view returns(uint) {
        Auction a = auctions[auctionId];
        return a.bids.length;
    }

    function getBidForAuctionByIdx(uint auctionId, uint idx) public view
    returns(address bidder, uint256 amount, uint timestamp) {
        Auction a = auctions[auctionId];
        require(idx <= a.bids.length - 1);

        Bid b = a.bids[idx];
        return (b.bidder, b.amount, b.timestamp);
    }

    function placeBid(uint auctionId) public payable returns(bool success) {
        require(registeredUser[msg.sender].status);

        Auction a = auctions[auctionId];
        require(a.seller != msg.sender);

        uint256 amount = msg.value;
        require(a.currentBid < amount);

        uint bidIdx = a.bids.length++;
        Bid b = a.bids[bidIdx];
        b.bidder = msg.sender;
        b.amount = amount;
        b.timestamp = now;
        a.currentBid = amount;

        auctionsBidOnByUser[b.bidder].push(auctionId);

        // Log refunds for the previous bidder
        if (bidIdx > 0) {
            Bid previousBid = a.bids[bidIdx - 1];
            refunds[previousBid.bidder] += previousBid.amount;
        }

        emit BidPlaced(auctionId, b.bidder, b.amount);
        return true;
    }

    function getRefundValue() public view returns(uint) {
        return refunds[msg.sender];
    }

    function withdrawRefund() public returns(bool) {
        uint refund = refunds[msg.sender];
        refunds[msg.sender] = 0;
        msg.sender.transfer(refund);
    }

    function endAuction(uint auctionId) public returns(bool success) {
        Auction a = auctions[auctionId];

        // Make sure auction hasn't already been ended
        require(a.status == AuctionStatus.Active);

        // require(block.number >= a.blockNumberOfDeadline); // Still learn more about this

        // No bids, make the auction inactive
        if (a.bids.length == 0) {
            a.status = AuctionStatus.Inactive;
            return true;
        }

        Bid topBid = a.bids[a.bids.length - 1];

        // If the auction hit its reserve price
        if (a.currentBid > a.startingPrice) {
            a.seller.transfer(topBid.amount);
            emit AuctionEndedWithWinner(auctionId, topBid.bidder, a.currentBid);
        }

        a.status = AuctionStatus.Inactive;
        return true;

    }
    /* End Auction Section ------------------------------------- */

    /* Time Section -------------------------------------------- */
    struct _DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    uint constant DAY_IN_SECONDS = 86400;
    uint constant YEAR_IN_SECONDS = 31536000;
    uint constant LEAP_YEAR_IN_SECONDS = 31622400;

    uint constant HOUR_IN_SECONDS = 3600;
    uint constant MINUTE_IN_SECONDS = 60;

    uint16 constant ORIGIN_YEAR = 1970;

    function isLeapYear(uint16 year) public pure returns(bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function leapYearsBefore(uint year) public pure returns(uint) {
        year -= 1;
        return year / 4 - year / 100 + year / 400;
    }

    function getDaysInMonth(uint8 month, uint16 year) public pure returns(uint8) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            return 31;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else if (isLeapYear(year)) {
            return 29;
        } else {
            return 28;
        }
    }

    function parseTimestamp(uint timestamp) internal pure returns(_DateTime dt) {
        uint secondsAccountedFor = 0;
        uint buf;
        uint8 i;

        // Year
        dt.year = getYear(timestamp);
        buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
        secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

        // Month
        uint secondsInMonth;
        for (i = 1; i <= 12; i++) {
            secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
            if (secondsInMonth + secondsAccountedFor > timestamp) {
                dt.month = i;
                break;
            }
            secondsAccountedFor += secondsInMonth;
        }

        // Day
        for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
            if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                dt.day = i;
                break;
            }
            secondsAccountedFor += DAY_IN_SECONDS;
        }

        // Hour
        dt.hour = getHour(timestamp);

        // Minute
        dt.minute = getMinute(timestamp);

        // Second
        dt.second = getSecond(timestamp);

        // Day of week.
        dt.weekday = getWeekday(timestamp);
    }

    function getYear(uint timestamp) public pure returns(uint16) {
        uint secondsAccountedFor = 0;
        uint16 year;
        uint numLeapYears;

        // Year
        year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > timestamp) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            } else {
                secondsAccountedFor -= YEAR_IN_SECONDS;
            }
            year -= 1;
        }
        return year;
    }

    function getMonth(uint timestamp) public pure returns(uint8) {
        return parseTimestamp(timestamp).month;
    }

    function getDay(uint timestamp) public pure returns(uint8) {
        return parseTimestamp(timestamp).day;
    }

    function getHour(uint timestamp) public pure returns(uint8) {
        return uint8((timestamp / 60 / 60) % 24);
    }

    function getMinute(uint timestamp) public pure returns(uint8) {
        return uint8((timestamp / 60) % 60);
    }

    function getSecond(uint timestamp) public pure returns(uint8) {
        return uint8(timestamp % 60);
    }

    function getWeekday(uint timestamp) public pure returns(uint8) {
        return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
    }

    function toTimestamp(uint16 year, uint8 month, uint8 day) public pure returns(uint timestamp) {
        return toTimestamp(year, month, day, 0, 0, 0);
    }

    function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) public pure returns(uint timestamp) {
        return toTimestamp(year, month, day, hour, 0, 0);
    }

    function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute) public pure returns(uint timestamp) {
        return toTimestamp(year, month, day, hour, minute, 0);
    }

    function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) public pure returns(uint timestamp) {
        uint16 i;

        // Year
        for (i = ORIGIN_YEAR; i < year; i++) {
            if (isLeapYear(i)) {
                timestamp += LEAP_YEAR_IN_SECONDS;
            } else {
                timestamp += YEAR_IN_SECONDS;
            }
        }

        // Month
        uint8[12] memory monthDayCounts;
        monthDayCounts[0] = 31;
        if (isLeapYear(year)) {
            monthDayCounts[1] = 29;
        } else {
            monthDayCounts[1] = 28;
        }
        monthDayCounts[2] = 31;
        monthDayCounts[3] = 30;
        monthDayCounts[4] = 31;
        monthDayCounts[5] = 30;
        monthDayCounts[6] = 31;
        monthDayCounts[7] = 31;
        monthDayCounts[8] = 30;
        monthDayCounts[9] = 31;
        monthDayCounts[10] = 30;
        monthDayCounts[11] = 31;

        for (i = 1; i < month; i++) {
            timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
        }

        // Day
        timestamp += DAY_IN_SECONDS * (day - 1);

        // Hour
        timestamp += HOUR_IN_SECONDS * (hour);

        // Minute
        timestamp += MINUTE_IN_SECONDS * (minute);

        // Second
        timestamp += second;

        return timestamp;
    }
    /* End Time Section ---------------------------------------- */
}