
pragma solidity ^0.8.19;

contract VotingGovernance {
    struct Proposal {
        bytes32 id;
        string title;
        string description;
        address proposer;
        uint64 startTime;
        uint64 endTime;
        uint128 forVotes;
        uint128 againstVotes;
        uint128 abstainVotes;
        bool executed;
        bool canceled;
        bytes32 descriptionHash;
    }

    struct Vote {
        bool hasVoted;
        uint8 support;
        uint128 votes;
    }

    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes32 => mapping(address => Vote)) public votes;
    mapping(address => uint128) public votingPower;

    bytes32[] public proposalIds;
    address public admin;
    uint64 public votingDelay;
    uint64 public votingPeriod;
    uint128 public proposalThreshold;
    uint128 public quorumVotes;

    bool private _locked;

    event ProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposer,
        string title,
        uint64 startTime,
        uint64 endTime
    );

    event VoteCast(
        address indexed voter,
        bytes32 indexed proposalId,
        uint8 support,
        uint128 votes
    );

    event ProposalExecuted(bytes32 indexed proposalId);
    event ProposalCanceled(bytes32 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint128 newPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        uint64 _votingDelay,
        uint64 _votingPeriod,
        uint128 _proposalThreshold,
        uint128 _quorumVotes
    ) {
        admin = msg.sender;
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumVotes = _quorumVotes;
    }

    function propose(
        string calldata title,
        string calldata description
    ) external returns (bytes32) {
        require(votingPower[msg.sender] >= proposalThreshold, "Insufficient voting power");
        require(bytes(title).length > 0, "Empty title");
        require(bytes(description).length > 0, "Empty description");

        bytes32 descriptionHash = keccak256(bytes(description));
        bytes32 proposalId = keccak256(
            abi.encodePacked(
                msg.sender,
                title,
                descriptionHash,
                block.timestamp
            )
        );

        require(proposals[proposalId].proposer == address(0), "Proposal exists");

        uint64 startTime = uint64(block.timestamp) + votingDelay;
        uint64 endTime = startTime + votingPeriod;

        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            proposer: msg.sender,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false,
            descriptionHash: descriptionHash
        });

        proposalIds.push(proposalId);

        emit ProposalCreated(proposalId, msg.sender, title, startTime, endTime);
        return proposalId;
    }

    function castVote(bytes32 proposalId, uint8 support) external nonReentrant {
        require(support <= 2, "Invalid support value");
        require(votingPower[msg.sender] > 0, "No voting power");

        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposer != address(0), "Proposal not found");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.executed, "Proposal executed");
        require(!proposal.canceled, "Proposal canceled");

        Vote storage vote = votes[proposalId][msg.sender];
        require(!vote.hasVoted, "Already voted");

        uint128 weight = votingPower[msg.sender];
        vote.hasVoted = true;
        vote.support = support;
        vote.votes = weight;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    function executeProposal(bytes32 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposer != address(0), "Proposal not found");
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");

        uint128 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        require(totalVotes >= quorumVotes, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(bytes32 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposer != address(0), "Proposal not found");
        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "Not authorized"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function setVotingPower(address account, uint128 power) external onlyAdmin {
        votingPower[account] = power;
        emit VotingPowerUpdated(account, power);
    }

    function updateGovernanceParams(
        uint64 _votingDelay,
        uint64 _votingPeriod,
        uint128 _proposalThreshold,
        uint128 _quorumVotes
    ) external onlyAdmin {
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumVotes = _quorumVotes;
    }

    function getProposal(bytes32 proposalId) external view returns (
        bytes32 id,
        string memory title,
        string memory description,
        address proposer,
        uint64 startTime,
        uint64 endTime,
        uint128 forVotes,
        uint128 againstVotes,
        uint128 abstainVotes,
        bool executed,
        bool canceled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.canceled
        );
    }

    function getProposalState(bytes32 proposalId) external view returns (uint8) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposer != address(0), "Proposal not found");

        if (proposal.canceled) {
            return 2;
        }

        if (proposal.executed) {
            return 7;
        }

        if (block.timestamp <= proposal.startTime) {
            return 0;
        }

        if (block.timestamp <= proposal.endTime) {
            return 1;
        }

        uint128 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;

        if (totalVotes < quorumVotes) {
            return 3;
        }

        if (proposal.forVotes <= proposal.againstVotes) {
            return 3;
        }

        return 4;
    }

    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    function hasVoted(bytes32 proposalId, address account) external view returns (bool) {
        return votes[proposalId][account].hasVoted;
    }
}
