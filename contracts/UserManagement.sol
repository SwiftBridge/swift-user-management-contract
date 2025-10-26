// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title UserManagement
 * @dev A contract for managing user profiles, authentication, and permissions
 * @author Swift v2 Team
 */
contract UserManagement is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // Events
    event UserRegistered(
        address indexed user,
        string username,
        uint256 timestamp
    );

    event ProfileUpdated(
        address indexed user,
        string username,
        string bio,
        string avatar
    );

    event UserVerified(
        address indexed user,
        bool isVerified
    );

    event UserBanned(
        address indexed user,
        address indexed admin,
        string reason
    );

    event UserUnbanned(
        address indexed user,
        address indexed admin
    );

    event PermissionGranted(
        address indexed user,
        string permission,
        address indexed granter
    );

    event PermissionRevoked(
        address indexed user,
        string permission,
        address indexed revoker
    );

    // Structs
    struct UserProfile {
        string username;
        string bio;
        string avatar;
        string email;
        string twitter;
        string github;
        string website;
        bool isVerified;
        bool isActive;
        bool isBanned;
        uint256 registeredAt;
        uint256 lastSeen;
        uint256 reputation;
        mapping(string => bool) permissions;
    }

    struct UserStats {
        uint256 messagesSent;
        uint256 messagesReceived;
        uint256 batchMessagesSent;
        uint256 batchTransactionsExecuted;
        uint256 reputation;
        uint256 joinDate;
    }

    struct VerificationRequest {
        address user;
        string verificationData;
        string verificationType;
        uint256 submittedAt;
        bool isProcessed;
        bool isApproved;
    }

    // State variables
    Counters.Counter private _userIdCounter;
    Counters.Counter private _verificationIdCounter;

    mapping(address => UserProfile) public userProfiles;
    mapping(address => UserStats) public userStats;
    mapping(string => address) public usernameToAddress;
    mapping(address => uint256[]) public userVerifications;
    mapping(uint256 => VerificationRequest) public verificationRequests;
    mapping(address => bool) public admins;
    mapping(address => bool) public moderators;

    // Constants
    uint256 public constant MIN_USERNAME_LENGTH = 3;
    uint256 public constant MAX_USERNAME_LENGTH = 20;
    uint256 public constant MAX_BIO_LENGTH = 500;
    uint256 public constant REGISTRATION_FEE = 0.000003 ether; // ~$0.009 at $3000 ETH
    uint256 public constant VERIFICATION_FEE = 0.000003 ether; // ~$0.009 at $3000 ETH

    // Modifiers
    modifier onlyRegisteredUser() {
        require(userProfiles[msg.sender].registeredAt > 0, "User not registered");
        _;
    }

    modifier onlyActiveUser() {
        require(userProfiles[msg.sender].isActive, "User not active");
        require(!userProfiles[msg.sender].isBanned, "User is banned");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner(), "Not an admin");
        _;
    }

    modifier onlyModerator() {
        require(
            moderators[msg.sender] || admins[msg.sender] || msg.sender == owner(),
            "Not a moderator"
        );
        _;
    }

    modifier validUsername(string memory _username) {
        require(bytes(_username).length >= MIN_USERNAME_LENGTH, "Username too short");
        require(bytes(_username).length <= MAX_USERNAME_LENGTH, "Username too long");
        require(usernameToAddress[_username] == address(0), "Username already taken");
        _;
    }

    constructor() {
        _userIdCounter.increment();
        _verificationIdCounter.increment();
        
        // Make owner an admin
        admins[msg.sender] = true;
    }

    /**
     * @dev Register a new user
     * @param _username Desired username
     * @param _bio User bio
     * @param _avatar Avatar URL
     */
    function registerUser(
        string memory _username,
        string memory _bio,
        string memory _avatar
    ) external payable nonReentrant validUsername(_username) {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(userProfiles[msg.sender].registeredAt == 0, "User already registered");
        require(bytes(_bio).length <= MAX_BIO_LENGTH, "Bio too long");

        uint256 userId = _userIdCounter.current();
        _userIdCounter.increment();

        UserProfile storage profile = userProfiles[msg.sender];
        profile.username = _username;
        profile.bio = _bio;
        profile.avatar = _avatar;
        profile.isVerified = false;
        profile.isActive = true;
        profile.isBanned = false;
        profile.registeredAt = block.timestamp;
        profile.lastSeen = block.timestamp;
        profile.reputation = 0;

        // Set default permissions
        profile.permissions["send_message"] = true;
        profile.permissions["receive_message"] = true;
        profile.permissions["create_batch"] = true;

        usernameToAddress[_username] = msg.sender;

        // Initialize user stats
        UserStats storage stats = userStats[msg.sender];
        stats.joinDate = block.timestamp;
        stats.reputation = 0;

        emit UserRegistered(msg.sender, _username, block.timestamp);
    }

    /**
     * @dev Update user profile
     * @param _username New username
     * @param _bio New bio
     * @param _avatar New avatar URL
     * @param _email New email
     * @param _twitter New Twitter handle
     * @param _github New GitHub username
     * @param _website New website URL
     */
    function updateProfile(
        string memory _username,
        string memory _bio,
        string memory _avatar,
        string memory _email,
        string memory _twitter,
        string memory _github,
        string memory _website
    ) external onlyRegisteredUser onlyActiveUser {
        require(bytes(_bio).length <= MAX_BIO_LENGTH, "Bio too long");
        
        // Check if username is being changed
        if (keccak256(bytes(_username)) != keccak256(bytes(userProfiles[msg.sender].username))) {
            require(usernameToAddress[_username] == address(0), "Username already taken");
            require(bytes(_username).length >= MIN_USERNAME_LENGTH, "Username too short");
            require(bytes(_username).length <= MAX_USERNAME_LENGTH, "Username too long");
            
            // Free up old username
            usernameToAddress[userProfiles[msg.sender].username] = address(0);
            usernameToAddress[_username] = msg.sender;
        }

        UserProfile storage profile = userProfiles[msg.sender];
        profile.username = _username;
        profile.bio = _bio;
        profile.avatar = _avatar;
        profile.email = _email;
        profile.twitter = _twitter;
        profile.github = _github;
        profile.website = _website;
        profile.lastSeen = block.timestamp;

        emit ProfileUpdated(msg.sender, _username, _bio, _avatar);
    }

    /**
     * @dev Submit verification request
     * @param _verificationData Data for verification
     * @param _verificationType Type of verification
     */
    function submitVerificationRequest(
        string memory _verificationData,
        string memory _verificationType
    ) external payable onlyRegisteredUser onlyActiveUser {
        require(msg.value >= VERIFICATION_FEE, "Insufficient verification fee");
        require(bytes(_verificationData).length > 0, "Verification data required");

        uint256 verificationId = _verificationIdCounter.current();
        _verificationIdCounter.increment();

        VerificationRequest storage request = verificationRequests[verificationId];
        request.user = msg.sender;
        request.verificationData = _verificationData;
        request.verificationType = _verificationType;
        request.submittedAt = block.timestamp;
        request.isProcessed = false;
        request.isApproved = false;

        userVerifications[msg.sender].push(verificationId);
    }

    /**
     * @dev Process verification request (admin only)
     * @param _verificationId ID of the verification request
     * @param _approved Whether to approve the request
     */
    function processVerificationRequest(
        uint256 _verificationId,
        bool _approved
    ) external onlyAdmin {
        require(_verificationId > 0 && _verificationId < _verificationIdCounter.current(), "Invalid verification ID");
        
        VerificationRequest storage request = verificationRequests[_verificationId];
        require(!request.isProcessed, "Request already processed");

        request.isProcessed = true;
        request.isApproved = _approved;

        if (_approved) {
            userProfiles[request.user].isVerified = true;
            emit UserVerified(request.user, true);
        }
    }

    /**
     * @dev Ban a user (admin only)
     * @param _user Address of the user to ban
     * @param _reason Reason for banning
     */
    function banUser(address _user, string memory _reason) external onlyAdmin {
        require(userProfiles[_user].registeredAt > 0, "User not registered");
        require(!userProfiles[_user].isBanned, "User already banned");
        require(_user != owner(), "Cannot ban owner");

        userProfiles[_user].isBanned = true;
        userProfiles[_user].isActive = false;

        emit UserBanned(_user, msg.sender, _reason);
    }

    /**
     * @dev Unban a user (admin only)
     * @param _user Address of the user to unban
     */
    function unbanUser(address _user) external onlyAdmin {
        require(userProfiles[_user].isBanned, "User not banned");

        userProfiles[_user].isBanned = false;
        userProfiles[_user].isActive = true;

        emit UserUnbanned(_user, msg.sender);
    }

    /**
     * @dev Grant permission to user
     * @param _user Address of the user
     * @param _permission Permission to grant
     */
    function grantPermission(address _user, string memory _permission) external onlyAdmin {
        require(userProfiles[_user].registeredAt > 0, "User not registered");
        
        userProfiles[_user].permissions[_permission] = true;
        emit PermissionGranted(_user, _permission, msg.sender);
    }

    /**
     * @dev Revoke permission from user
     * @param _user Address of the user
     * @param _permission Permission to revoke
     */
    function revokePermission(address _user, string memory _permission) external onlyAdmin {
        require(userProfiles[_user].registeredAt > 0, "User not registered");
        
        userProfiles[_user].permissions[_permission] = false;
        emit PermissionRevoked(_user, _permission, msg.sender);
    }

    /**
     * @dev Update user reputation
     * @param _user Address of the user
     * @param _reputationChange Change in reputation (can be negative)
     */
    function updateReputation(address _user, int256 _reputationChange) external onlyModerator {
        require(userProfiles[_user].registeredAt > 0, "User not registered");
        
        UserStats storage stats = userStats[_user];
        if (_reputationChange > 0) {
            stats.reputation += uint256(_reputationChange);
        } else {
            uint256 decrease = uint256(-_reputationChange);
            if (stats.reputation >= decrease) {
                stats.reputation -= decrease;
            } else {
                stats.reputation = 0;
            }
        }
        
        userProfiles[_user].reputation = stats.reputation;
    }

    /**
     * @dev Update user activity stats
     * @param _user Address of the user
     * @param _statType Type of stat to update
     * @param _increment Amount to increment by
     */
    function updateUserStats(
        address _user,
        string memory _statType,
        uint256 _increment
    ) external {
        require(
            msg.sender == owner() ||
            admins[msg.sender] ||
            moderators[msg.sender],
            "Not authorized to update stats"
        );

        UserStats storage stats = userStats[_user];
        
        if (keccak256(bytes(_statType)) == keccak256("messages_sent")) {
            stats.messagesSent += _increment;
        } else if (keccak256(bytes(_statType)) == keccak256("messages_received")) {
            stats.messagesReceived += _increment;
        } else if (keccak256(bytes(_statType)) == keccak256("batch_messages_sent")) {
            stats.batchMessagesSent += _increment;
        } else if (keccak256(bytes(_statType)) == keccak256("batch_transactions_executed")) {
            stats.batchTransactionsExecuted += _increment;
        }
    }

    /**
     * @dev Get user profile
     * @param _user Address of the user
     * @return Profile data
     */
    function getUserProfile(address _user) external view returns (
        string memory username,
        string memory bio,
        string memory avatar,
        string memory email,
        string memory twitter,
        string memory github,
        string memory website,
        bool isVerified,
        bool isActive,
        bool isBanned,
        uint256 registeredAt,
        uint256 lastSeen,
        uint256 reputation
    ) {
        UserProfile storage profile = userProfiles[_user];
        return (
            profile.username,
            profile.bio,
            profile.avatar,
            profile.email,
            profile.twitter,
            profile.github,
            profile.website,
            profile.isVerified,
            profile.isActive,
            profile.isBanned,
            profile.registeredAt,
            profile.lastSeen,
            profile.reputation
        );
    }

    /**
     * @dev Get user stats
     * @param _user Address of the user
     * @return Stats data
     */
    function getUserStats(address _user) external view returns (
        uint256 messagesSent,
        uint256 messagesReceived,
        uint256 batchMessagesSent,
        uint256 batchTransactionsExecuted,
        uint256 reputation,
        uint256 joinDate
    ) {
        UserStats storage stats = userStats[_user];
        return (
            stats.messagesSent,
            stats.messagesReceived,
            stats.batchMessagesSent,
            stats.batchTransactionsExecuted,
            stats.reputation,
            stats.joinDate
        );
    }

    /**
     * @dev Check if user has permission
     * @param _user Address of the user
     * @param _permission Permission to check
     * @return True if user has permission
     */
    function hasPermission(address _user, string memory _permission) external view returns (bool) {
        return userProfiles[_user].permissions[_permission];
    }

    /**
     * @dev Get address by username
     * @param _username Username to look up
     * @return Address of the user
     */
    function getAddressByUsername(string memory _username) external view returns (address) {
        return usernameToAddress[_username];
    }

    /**
     * @dev Add admin
     * @param _admin Address to make admin
     */
    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
    }

    /**
     * @dev Remove admin
     * @param _admin Address to remove admin status from
     */
    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != owner(), "Cannot remove owner admin status");
        admins[_admin] = false;
    }

    /**
     * @dev Add moderator
     * @param _moderator Address to make moderator
     */
    function addModerator(address _moderator) external onlyOwner {
        moderators[_moderator] = true;
    }

    /**
     * @dev Remove moderator
     * @param _moderator Address to remove moderator status from
     */
    function removeModerator(address _moderator) external onlyOwner {
        moderators[_moderator] = false;
    }

    /**
     * @dev Get total user count
     * @return Total number of registered users
     */
    function getTotalUserCount() external view returns (uint256) {
        return _userIdCounter.current() - 1;
    }

    /**
     * @dev Withdraw contract balance (only owner)
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }
}
