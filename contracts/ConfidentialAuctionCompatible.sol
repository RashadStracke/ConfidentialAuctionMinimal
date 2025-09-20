// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Compatible Confidential Auction with simulated FHE types
// Works on all networks while maintaining FHE interface
contract ConfidentialAuctionCompatible {

    // Simulated FHE types for compatibility
    type euint64 is uint256;
    type ebool is uint256;

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
        euint64 highestBidAmount; // Simulated encrypted type
        address highestBidder;
        uint256 bidCount;
        ebool isHighBid; // Simulated encrypted boolean
    }

    struct Bid {
        address bidder;
        euint64 amount; // Simulated encrypted amount
        ebool isHighBid; // Simulated encrypted boolean
        string comments;
        uint256 timestamp;
        bool isRevealed;
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

    // Simulated FHE functions
    function asEuint64(uint64 value) internal pure returns (euint64) {
        return euint64.wrap(uint256(value));
    }

    function asEbool(bool value) internal pure returns (ebool) {
        return ebool.wrap(value ? 1 : 0);
    }

    function decrypt(euint64 value) internal pure returns (uint64) {
        return uint64(euint64.unwrap(value));
    }

    function decrypt(ebool value) internal pure returns (bool) {
        return ebool.unwrap(value) == 1;
    }

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
            highestBidAmount: asEuint64(0),
            highestBidder: address(0),
            bidCount: 0,
            isHighBid: asEbool(false)
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

        // Encrypt bid amount and status using simulated FHE
        euint64 encryptedAmount = asEuint64(uint64(_bidAmount));
        ebool encryptedIsHigh = asEbool(_isHighBid);

        // Update highest bid if this is marked as high bid
        if (_isHighBid && _bidAmount > decrypt(auction.highestBidAmount)) {
            auction.highestBidAmount = encryptedAmount;
            auction.highestBidder = msg.sender;
            auction.isHighBid = encryptedIsHigh;
        }

        // Store encrypted bid
        auctionBids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: encryptedAmount,
            isHighBid: encryptedIsHigh,
            comments: _comments,
            timestamp: block.timestamp,
            isRevealed: false
        }));

        auction.bidCount++;
        hasUserBid[msg.sender][_auctionId] = true;

        emit BidPlaced(_auctionId, msg.sender, _comments, block.timestamp);
    }

    // View functions that return regular types (not encrypted)
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
        return decrypt(auctions[_auctionId].highestBidAmount);
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

    // Admin functions
    function endAuction(uint256 _auctionId) external {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].creator == msg.sender, "Only creator can end auction");

        auctions[_auctionId].isActive = false;
    }

    function withdrawFunds() external {
        require(msg.sender == address(this), "Only contract owner");
        payable(msg.sender).transfer(address(this).balance);
    }
}