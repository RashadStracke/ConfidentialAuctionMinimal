// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@fhevm/solidity/lib/FHE.sol";

// Confidential Auction using Zama FHEVM
contract ConfidentialAuction {
    using FHE for euint64;
    using FHE for ebool;

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
        euint64 highestBidAmount;
        address highestBidder;
        uint256 bidCount;
    }

    struct Bid {
        address bidder;
        euint64 amount;
        ebool isHighBid;
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
        uint256 timestamp
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address winner,
        uint256 winningBid
    );

    constructor() {}

    function createAuction(
        string memory _title,
        string memory _description,
        string memory _category,
        uint256 _minimumBid
    ) public {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(bytes(_category).length > 0, "Category cannot be empty");
        require(_minimumBid > 0, "Minimum bid must be greater than 0");

        uint256 auctionId = nextAuctionId++;
        uint256 endTime = block.timestamp + 7 days; // 7 day auction duration

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
            highestBidAmount: FHE.asEuint64(0),
            highestBidder: address(0),
            bidCount: 0
        });

        userAuctions[msg.sender].push(auctionId);
        totalAuctions++;

        emit AuctionCreated(
            auctionId,
            _title,
            _category,
            _minimumBid,
            msg.sender,
            endTime
        );
    }

    function placeBid(
        uint256 _auctionId,
        bool _isHighBid,
        uint256 _bidAmount,
        string memory _comments
    ) public payable {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].isActive, "Auction is not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        require(msg.sender != auctions[_auctionId].creator, "Cannot bid on your own auction");
        require(!hasUserBid[msg.sender][_auctionId], "You have already placed a bid on this auction");
        require(msg.value >= auctions[_auctionId].minimumBid, "Bid below minimum amount");

        // Convert boolean to encrypted boolean using FHEVM
        ebool encryptedIsHighBid = FHE.asEbool(_isHighBid);

        // Convert bid amount to encrypted uint64 using FHEVM (cast uint256 to uint64)
        euint64 encryptedBidAmount = FHE.asEuint64(uint64(_bidAmount));

        // Store the encrypted bid
        auctionBids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: encryptedBidAmount,
            isHighBid: encryptedIsHighBid,
            comments: _comments,
            timestamp: block.timestamp,
            isRevealed: false
        }));

        // Update auction bid count
        auctions[_auctionId].bidCount++;

        // Mark that user has bid on this auction
        hasUserBid[msg.sender][_auctionId] = true;

        // Check if this is the highest bid (using FHE comparison)
        euint64 currentHighest = auctions[_auctionId].highestBidAmount;
        ebool isNewHighest = encryptedBidAmount.gt(currentHighest);

        // Conditionally update highest bid using FHE select
        auctions[_auctionId].highestBidAmount = FHE.select(
            isNewHighest,
            encryptedBidAmount,
            currentHighest
        );

        // Update highest bidder if this is the highest bid
        if (_bidAmount > 0) { // Simple check for demo purposes
            auctions[_auctionId].highestBidder = msg.sender;
        }

        emit BidPlaced(_auctionId, msg.sender, block.timestamp);
    }

    function endAuction(uint256 _auctionId) public {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].isActive, "Auction is not active");
        require(
            block.timestamp >= auctions[_auctionId].endTime ||
            msg.sender == auctions[_auctionId].creator,
            "Auction has not ended yet and you are not the creator"
        );

        auctions[_auctionId].isActive = false;

        // Transfer the winning bid to auction creator
        address winner = auctions[_auctionId].highestBidder;
        if (winner != address(0)) {
            // In a real implementation, you would decrypt the highest bid amount
            // For now, we'll use a placeholder value
            uint256 winningBid = auctions[_auctionId].minimumBid;

            payable(auctions[_auctionId].creator).transfer(winningBid);
            emit AuctionEnded(_auctionId, winner, winningBid);
        }
    }

    function getActiveAuctions() public view returns (Auction[] memory) {
        uint256 activeCount = 0;

        // Count active auctions
        for (uint256 i = 1; i < nextAuctionId; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeCount++;
            }
        }

        Auction[] memory activeAuctions = new Auction[](activeCount);
        uint256 currentIndex = 0;

        // Populate active auctions array
        for (uint256 i = 1; i < nextAuctionId; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeAuctions[currentIndex] = auctions[i];
                currentIndex++;
            }
        }

        return activeAuctions;
    }

    function getUserAuctions(address _user) public view returns (uint256[] memory) {
        return userAuctions[_user];
    }

    function getAuctionBidCount(uint256 _auctionId) public view returns (uint256) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].bidCount;
    }

    function hasPlacedBid(address _user, uint256 _auctionId) public view returns (bool) {
        return hasUserBid[_user][_auctionId];
    }

    // Function to get auction details by ID
    function getAuction(uint256 _auctionId) public view returns (Auction memory) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId];
    }

    // Function to get total counts for stats
    function getTotalCounts() public view returns (uint256 totalAuctionCount, uint256 activeAuctionCount) {
        uint256 activeCount = 0;

        for (uint256 i = 1; i < nextAuctionId; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeCount++;
            }
        }

        return (totalAuctions, activeCount);
    }

    // Emergency function to withdraw contract balance (only for testing)
    function emergencyWithdraw() public {
        require(msg.sender == address(this), "Only contract can withdraw");
        payable(msg.sender).transfer(address(this).balance);
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}
}