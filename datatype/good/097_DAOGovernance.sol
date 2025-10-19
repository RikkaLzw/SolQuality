
pragma solidity ^0.8.19;

contract DAOGovernance {

    bytes32 public constant DOMAIN_SEPARATOR = keccak256("DAOGovernance");

    struct Proposal {
        bytes32 id;
        address proposer;
        bytes32 title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint32 startTime;
        uint32 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    struct Member {
        bool isActive;
        uint128 votingPower;
        uint32 joinTime;
    }


    mapping(bytes32 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => bool) public isAdmin;


    bytes32[] public proposalIds;
    address[] public memberAddresses;


    uint32 public constant VOTING_PERIOD = 7 days;
    uint32 public constant MIN_VOTING_PERIOD = 1 days;
    uint128 public constant MIN_VOTING_POWER = 1;
    uint8 public constant QUORUM_PERCENTAGE = 51;


    uint256 public totalVotingPower;
    uint32 public proposalCount;
    address public owner;
    bool public paused;


    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, bytes32 title);
    event VoteCast(bytes32 indexed proposalId, address indexed voter, bool support, uint128 votingPower);
    event ProposalExecuted(bytes32 indexed proposalId);
    event ProposalCanceled(bytes32 indexed proposalId);
    event MemberAdded(address indexed member, uint128 votingPower);
    event MemberRemoved(address indexed member);
    event VotingPowerUpdated(address indexed member, uint128 newVotingPower);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || msg.sender == owner, "Not admin");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not active member");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validProposal(bytes32 _proposalId) {
        require(proposals[_proposalId].proposer != address(0), "Proposal does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;


        members[msg.sender] = Member({
            isActive: true,
            votingPower: 100,
            joinTime: uint32(block.timestamp)
        });
        memberAddresses.push(msg.sender);
        totalVotingPower = 100;
    }


    function addMember(address _member, uint128 _votingPower) external onlyAdmin notPaused {
        require(_member != address(0), "Invalid address");
        require(_votingPower >= MIN_VOTING_POWER, "Insufficient voting power");
        require(!members[_member].isActive, "Already a member");

        members[_member] = Member({
            isActive: true,
            votingPower: _votingPower,
            joinTime: uint32(block.timestamp)
        });

        memberAddresses.push(_member);
        totalVotingPower += _votingPower;

        emit MemberAdded(_member, _votingPower);
    }

    function removeMember(address _member) external onlyAdmin {
        require(members[_member].isActive, "Not an active member");
        require(_member != owner, "Cannot remove owner");

        uint128 votingPower = members[_member].votingPower;
        members[_member].isActive = false;
        members[_member].votingPower = 0;

        totalVotingPower -= votingPower;


        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (memberAddresses[i] == _member) {
                memberAddresses[i] = memberAddresses[memberAddresses.length - 1];
                memberAddresses.pop();
                break;
            }
        }

        emit MemberRemoved(_member);
    }

    function updateVotingPower(address _member, uint128 _newVotingPower) external onlyAdmin {
        require(members[_member].isActive, "Not an active member");
        require(_newVotingPower >= MIN_VOTING_POWER, "Insufficient voting power");

        uint128 oldVotingPower = members[_member].votingPower;
        members[_member].votingPower = _newVotingPower;

        if (_newVotingPower > oldVotingPower) {
            totalVotingPower += (_newVotingPower - oldVotingPower);
        } else {
            totalVotingPower -= (oldVotingPower - _newVotingPower);
        }

        emit VotingPowerUpdated(_member, _newVotingPower);
    }


    function createProposal(bytes32 _title, string calldata _description) external onlyMember notPaused returns (bytes32) {
        require(_title != bytes32(0), "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        bytes32 proposalId = keccak256(abi.encodePacked(
            msg.sender,
            _title,
            block.timestamp,
            proposalCount
        ));

        require(proposals[proposalId].proposer == address(0), "Proposal ID collision");

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.startTime = uint32(block.timestamp);
        newProposal.endTime = uint32(block.timestamp + VOTING_PERIOD);
        newProposal.executed = false;
        newProposal.canceled = false;

        proposalIds.push(proposalId);
        proposalCount++;

        emit ProposalCreated(proposalId, msg.sender, _title);
        return proposalId;
    }

    function vote(bytes32 _proposalId, bool _support) external onlyMember notPaused validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint128 votingPower = members[msg.sender].votingPower;
        require(votingPower > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = _support;

        if (_support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
    }

    function executeProposal(bytes32 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 requiredQuorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        require(totalVotes >= requiredQuorum, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function cancelProposal(bytes32 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(
            msg.sender == proposal.proposer || isAdmin[msg.sender] || msg.sender == owner,
            "Not authorized to cancel"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;

        emit ProposalCanceled(_proposalId);
    }


    function getProposal(bytes32 _proposalId) external view returns (
        bytes32 id,
        address proposer,
        bytes32 title,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint32 startTime,
        uint32 endTime,
        bool executed,
        bool canceled
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.canceled
        );
    }

    function hasVoted(bytes32 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getVoteChoice(bytes32 _proposalId, address _voter) external view returns (bool) {
        require(proposals[_proposalId].hasVoted[_voter], "Has not voted");
        return proposals[_proposalId].voteChoice[_voter];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    function getMemberCount() external view returns (uint256) {
        return memberAddresses.length;
    }

    function isProposalActive(bytes32 _proposalId) external view returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer != address(0) &&
            block.timestamp >= proposal.startTime &&
            block.timestamp <= proposal.endTime &&
            !proposal.executed &&
            !proposal.canceled
        );
    }


    function addAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Invalid address");
        isAdmin[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != owner, "Cannot remove owner");
        isAdmin[_admin] = false;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        require(_newOwner != owner, "Same owner");

        isAdmin[_newOwner] = true;
        owner = _newOwner;
    }
}
