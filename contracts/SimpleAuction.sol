// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Simplified auction contract without stack depth issues
contract SimpleAuction {

    struct Auction {
        uint256 id;
        string title;
        string description;
        string category;
        uint256 minimumBid;
        address creator;
        uint256 timestamp;
        bool isActive;
        uint256 endTime;
        uint256 highestBidAmount;
        address highestBidder;
        uint256 bidCount;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        bool isHighBid;
        string comments;
        uint256 timestamp;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => mapping(uint256 => bool)) public hasUserBid;

    uint256 public nextAuctionId = 1;
    uint256 public totalAuctions = 0;

    event AuctionCreated(
        uint256 indexed auctionId,
        string title,
        string category,
        uint256 minimumBid,
        address indexed creator,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        string comments,
        uint256 timestamp
    );

    constructor() {}

    function createAuction(
        string memory _title,
        string memory _description,
        string memory _category,
        uint256 _minimumBid
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_minimumBid > 0, "Minimum bid must be greater than 0");

        uint256 auctionId = nextAuctionId;
        uint256 endTime = block.timestamp + 7 days;

        auctions[auctionId] = Auction({
            id: auctionId,
            title: _title,
            description: _description,
            category: _category,
            minimumBid: _minimumBid,
            creator: msg.sender,
            timestamp: block.timestamp,
            isActive: true,
            endTime: endTime,
            highestBidAmount: 0,
            highestBidder: address(0),
            bidCount: 0
        });

        userAuctions[msg.sender].push(auctionId);
        totalAuctions++;
        nextAuctionId++;

        emit AuctionCreated(auctionId, _title, _category, _minimumBid, msg.sender, endTime);
    }

    function placeBid(
        uint256 _auctionId,
        bool _isHighBid,
        uint256 _bidAmount,
        string memory _comments
    ) external payable {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].isActive, "Auction is not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        require(_bidAmount >= auctions[_auctionId].minimumBid, "Bid too low");
        require(msg.value >= _bidAmount, "Insufficient payment");

        Auction storage auction = auctions[_auctionId];

        // Update highest bid if this is marked as high bid
        if (_isHighBid && _bidAmount > auction.highestBidAmount) {
            auction.highestBidAmount = _bidAmount;
            auction.highestBidder = msg.sender;
        }

        // Store the bid
        auctionBids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: _bidAmount,
            isHighBid: _isHighBid,
            comments: _comments,
            timestamp: block.timestamp
        }));

        auction.bidCount++;
        hasUserBid[msg.sender][_auctionId] = true;

        emit BidPlaced(_auctionId, msg.sender, _comments, block.timestamp);
    }

    function getTotalCounts() external view returns (uint256 totalAuctionCount, uint256 activeAuctionCount) {
        uint256 activeCount = 0;
        for (uint256 i = 1; i < nextAuctionId; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeCount++;
            }
        }
        return (totalAuctions, activeCount);
    }

    function getAuctionBasicInfo(uint256 _auctionId) external view returns (
        string memory title,
        string memory description,
        string memory category,
        uint256 minimumBid,
        address creator
    ) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        return (auction.title, auction.description, auction.category, auction.minimumBid, auction.creator);
    }

    function getAuctionStatus(uint256 _auctionId) external view returns (
        uint256 timestamp,
        bool isActive,
        uint256 endTime,
        uint256 bidCount
    ) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        return (auction.timestamp, auction.isActive && block.timestamp < auction.endTime, auction.endTime, auction.bidCount);
    }

    function getHighestBidAmount(uint256 _auctionId) external view returns (uint256) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].highestBidAmount;
    }

    function getHighestBidder(uint256 _auctionId) external view returns (address) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].highestBidder;
    }

    function getBidCount(uint256 _auctionId) external view returns (uint256) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].bidCount;
    }

    function getUserAuctions(address _user) external view returns (uint256[] memory) {
        return userAuctions[_user];
    }

    function hasUserBidOnAuction(address _user, uint256 _auctionId) external view returns (bool) {
        return hasUserBid[_user][_auctionId];
    }

    function endAuction(uint256 _auctionId) external {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].creator == msg.sender, "Only creator can end auction");
        auctions[_auctionId].isActive = false;
    }
}