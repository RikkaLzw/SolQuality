
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
        bool cancelled;
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
    mapping(address => bool) public admins;

    bytes32[] public proposalIds;
    address[] public memberAddresses;

    address public owner;
    uint256 public totalVotingPower;
    uint32 public votingDuration;
    uint128 public minimumVotingPower;
    uint8 public quorumPercentage;

    bool private locked;

    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, bytes32 title);
    event VoteCast(bytes32 indexed proposalId, address indexed voter, bool support, uint128 votingPower);
    event ProposalExecuted(bytes32 indexed proposalId);
    event ProposalCancelled(bytes32 indexed proposalId);
    event MemberAdded(address indexed member, uint128 votingPower);
    event MemberRemoved(address indexed member);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Not admin");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not active member");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier validProposal(bytes32 proposalId) {
        require(proposals[proposalId].proposer != address(0), "Proposal does not exist");
        _;
    }

    constructor(
        uint32 _votingDuration,
        uint128 _minimumVotingPower,
        uint8 _quorumPercentage
    ) {
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Invalid quorum percentage");
        require(_votingDuration > 0, "Invalid voting duration");

        owner = msg.sender;
        votingDuration = _votingDuration;
        minimumVotingPower = _minimumVotingPower;
        quorumPercentage = _quorumPercentage;
        admins[msg.sender] = true;


        members[msg.sender] = Member({
            isActive: true,
            votingPower: 1000,
            joinTime: uint32(block.timestamp)
        });
        memberAddresses.push(msg.sender);
        totalVotingPower = 1000;
    }

    function addMember(address member, uint128 votingPower) external onlyAdmin {
        require(member != address(0), "Invalid address");
        require(!members[member].isActive, "Already a member");
        require(votingPower > 0, "Invalid voting power");

        members[member] = Member({
            isActive: true,
            votingPower: votingPower,
            joinTime: uint32(block.timestamp)
        });

        memberAddresses.push(member);
        totalVotingPower += votingPower;

        emit MemberAdded(member, votingPower);
    }

    function removeMember(address member) external onlyAdmin {
        require(members[member].isActive, "Not an active member");
        require(member != owner, "Cannot remove owner");

        uint128 memberVotingPower = members[member].votingPower;
        members[member].isActive = false;
        members[member].votingPower = 0;

        totalVotingPower -= memberVotingPower;


        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (memberAddresses[i] == member) {
                memberAddresses[i] = memberAddresses[memberAddresses.length - 1];
                memberAddresses.pop();
                break;
            }
        }

        emit MemberRemoved(member);
    }

    function addAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid address");
        require(!admins[admin], "Already an admin");

        admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyOwner {
        require(admins[admin], "Not an admin");
        require(admin != owner, "Cannot remove owner");

        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function createProposal(
        bytes32 title,
        string calldata description
    ) external onlyMember returns (bytes32 proposalId) {
        require(members[msg.sender].votingPower >= minimumVotingPower, "Insufficient voting power");
        require(title != bytes32(0), "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        proposalId = keccak256(abi.encodePacked(
            msg.sender,
            title,
            block.timestamp,
            block.number
        ));

        require(proposals[proposalId].proposer == address(0), "Proposal ID collision");

        uint32 startTime = uint32(block.timestamp);
        uint32 endTime = startTime + votingDuration;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;
        newProposal.executed = false;
        newProposal.cancelled = false;

        proposalIds.push(proposalId);

        emit ProposalCreated(proposalId, msg.sender, title);
    }

    function vote(bytes32 proposalId, bool support) external onlyMember validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint128 votingPower = members[msg.sender].votingPower;
        require(votingPower > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        if (support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }

    function executeProposal(bytes32 proposalId) external validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 requiredQuorum = (totalVotingPower * quorumPercentage) / 100;

        require(totalVotes >= requiredQuorum, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(bytes32 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            msg.sender == proposal.proposer || admins[msg.sender] || msg.sender == owner,
            "Not authorized to cancel"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Already cancelled");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    function getProposal(bytes32 proposalId) external view validProposal(proposalId) returns (
        bytes32 id,
        address proposer,
        bytes32 title,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint32 startTime,
        uint32 endTime,
        bool executed,
        bool cancelled
    ) {
        Proposal storage proposal = proposals[proposalId];
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
            proposal.cancelled
        );
    }

    function hasVoted(bytes32 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(bytes32 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    function getMemberCount() external view returns (uint256) {
        return memberAddresses.length;
    }

    function updateVotingDuration(uint32 newDuration) external onlyOwner {
        require(newDuration > 0, "Invalid duration");
        votingDuration = newDuration;
    }

    function updateQuorumPercentage(uint8 newPercentage) external onlyOwner {
        require(newPercentage > 0 && newPercentage <= 100, "Invalid percentage");
        quorumPercentage = newPercentage;
    }

    function updateMinimumVotingPower(uint128 newMinimum) external onlyOwner {
        minimumVotingPower = newMinimum;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        require(newOwner != owner, "Same owner");

        admins[owner] = false;
        admins[newOwner] = true;
        owner = newOwner;
    }
}
