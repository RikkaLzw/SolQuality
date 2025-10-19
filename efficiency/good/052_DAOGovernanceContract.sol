
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) votes;
    }

    struct ProposalCore {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
    }

    IERC20 public immutable governanceToken;

    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000e18;
    uint256 public constant QUORUM_PERCENTAGE = 4;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => uint256) public lastProposalTime;


    struct GovernanceSettings {
        uint128 minVotingPeriod;
        uint128 maxVotingPeriod;
        bool paused;
    }
    GovernanceSettings public settings;

    address public admin;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier notPaused() {
        require(!settings.paused, "Contract paused");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        _;
    }

    constructor(address _governanceToken, address _admin) {
        require(_governanceToken != address(0), "Invalid token address");
        require(_admin != address(0), "Invalid admin address");

        governanceToken = IERC20(_governanceToken);
        admin = _admin;
        settings = GovernanceSettings({
            minVotingPeriod: uint128(1 days),
            maxVotingPeriod: uint128(7 days),
            paused: false
        });
    }

    function createProposal(string calldata description) external notPaused returns (uint256) {
        require(bytes(description).length > 0, "Empty description");
        require(bytes(description).length <= 1000, "Description too long");
        require(governanceToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD, "Insufficient tokens");
        require(block.timestamp >= lastProposalTime[msg.sender] + 1 hours, "Proposal cooldown");


        uint256 proposerBalance = governanceToken.balanceOf(msg.sender);
        require(proposerBalance >= PROPOSAL_THRESHOLD, "Insufficient voting power");

        unchecked {
            ++proposalCount;
        }

        uint256 proposalId = proposalCount;
        Proposal storage proposal = proposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;

        lastProposalTime[msg.sender] = block.timestamp;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, uint8 support) external validProposal(proposalId) notPaused {
        require(support <= 2, "Invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed && !proposal.canceled, "Proposal finalized");


        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = support;


        if (support == 0) {
            unchecked {
                proposal.againstVotes += voterBalance;
            }
        } else if (support == 1) {
            unchecked {
                proposal.forVotes += voterBalance;
            }
        } else {
            unchecked {
                proposal.abstainVotes += voterBalance;
            }
        }

        emit VoteCast(proposalId, msg.sender, support, voterBalance);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed && !proposal.canceled, "Already finalized");


        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorum = (totalSupply * QUORUM_PERCENTAGE) / 100;

        uint256 totalVotes;
        unchecked {
            totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        }

        require(totalVotes >= quorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");
        require(block.timestamp >= proposal.endTime + EXECUTION_DELAY, "Execution delay not met");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed && !proposal.canceled, "Already finalized");
        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "Not authorized"
        );

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }

    function getProposal(uint256 proposalId) external view validProposal(proposalId)
        returns (ProposalCore memory) {
        Proposal storage proposal = proposals[proposalId];
        return ProposalCore({
            id: proposal.id,
            proposer: proposal.proposer,
            description: proposal.description,
            forVotes: proposal.forVotes,
            againstVotes: proposal.againstVotes,
            abstainVotes: proposal.abstainVotes,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed,
            canceled: proposal.canceled
        });
    }

    function getVote(uint256 proposalId, address voter) external view validProposal(proposalId)
        returns (bool hasVoted, uint8 vote) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.hasVoted[voter], proposal.votes[voter]);
    }

    function getProposalState(uint256 proposalId) external view validProposal(proposalId)
        returns (uint8) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) return 0;
        if (proposal.executed) return 1;
        if (block.timestamp <= proposal.endTime) return 2;


        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorum = (totalSupply * QUORUM_PERCENTAGE) / 100;

        uint256 totalVotes;
        unchecked {
            totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        }

        if (totalVotes < quorum) return 3;
        if (proposal.forVotes <= proposal.againstVotes) return 4;
        if (block.timestamp < proposal.endTime + EXECUTION_DELAY) return 5;
        return 6;
    }

    function quorum() external view returns (uint256) {
        return (governanceToken.totalSupply() * QUORUM_PERCENTAGE) / 100;
    }

    function setPaused(bool _paused) external onlyAdmin {
        settings.paused = _paused;
    }

    function updateVotingPeriods(uint128 _minPeriod, uint128 _maxPeriod) external onlyAdmin {
        require(_minPeriod > 0 && _maxPeriod >= _minPeriod, "Invalid periods");
        settings.minVotingPeriod = _minPeriod;
        settings.maxVotingPeriod = _maxPeriod;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        admin = newAdmin;
    }
}
