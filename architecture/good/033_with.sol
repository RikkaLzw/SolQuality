
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract DAOGovernanceContract is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant MINIMUM_QUORUM = 25;
    uint256 public constant PROPOSAL_THRESHOLD = 1;
    uint256 public constant MAX_OPERATIONS = 10;


    IERC20 public immutable governanceToken;
    uint256 public proposalCount;
    uint256 public totalSupply;

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) votes;
    }

    struct VotingPower {
        uint256 balance;
        uint256 delegated;
        address delegate;
    }


    mapping(uint256 => Proposal) public proposals;
    mapping(address => VotingPower) public votingPowers;
    mapping(address => mapping(uint256 => bool)) public proposalVotes;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);


    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        require(isActiveProposal(proposalId), "Proposal not active");
        _;
    }

    modifier onlyExecutableProposal(uint256 proposalId) {
        require(isExecutableProposal(proposalId), "Proposal not executable");
        _;
    }

    modifier hasVotingPower(address account) {
        require(getVotingPower(account) > 0, "No voting power");
        _;
    }

    modifier hasNotVoted(uint256 proposalId, address voter) {
        require(!proposals[proposalId].hasVoted[voter], "Already voted");
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
        totalSupply = governanceToken.totalSupply();
    }


    function createProposal(
        string memory title,
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(targets.length == values.length && targets.length == calldatas.length, "Invalid arrays length");
        require(targets.length > 0 && targets.length <= MAX_OPERATIONS, "Invalid operations count");
        require(hasProposalThreshold(msg.sender), "Insufficient tokens to create proposal");

        proposalCount = proposalCount.add(1);
        uint256 proposalId = proposalCount;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.targets = targets;
        proposal.values = values;
        proposal.calldatas = calldatas;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp.add(VOTING_PERIOD);
        proposal.executionTime = proposal.endTime.add(EXECUTION_DELAY);

        emit ProposalCreated(proposalId, msg.sender, title, proposal.startTime, proposal.endTime);
        return proposalId;
    }


    function castVote(uint256 proposalId, bool support)
        external
        validProposal(proposalId)
        onlyActiveProposal(proposalId)
        hasVotingPower(msg.sender)
        hasNotVoted(proposalId, msg.sender)
        nonReentrant
    {
        uint256 weight = getVotingPower(msg.sender);
        Proposal storage proposal = proposals[proposalId];

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = weight;

        if (support) {
            proposal.forVotes = proposal.forVotes.add(weight);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(weight);
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }


    function executeProposal(uint256 proposalId)
        external
        validProposal(proposalId)
        onlyExecutableProposal(proposalId)
        nonReentrant
    {
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success,) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, "Transaction execution reverted");
        }

        emit ProposalExecuted(proposalId);
    }


    function cancelProposal(uint256 proposalId)
        external
        validProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Only proposer or owner can cancel"
        );
        require(!proposal.executed && !proposal.canceled, "Proposal already finalized");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }


    function delegate(address delegatee) external {
        address currentDelegate = votingPowers[msg.sender].delegate;
        require(delegatee != currentDelegate, "Already delegated to this address");

        _delegate(msg.sender, delegatee);
    }


    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = votingPowers[delegator].delegate;
        uint256 delegatorBalance = governanceToken.balanceOf(delegator);

        votingPowers[delegator].delegate = delegatee;

        if (currentDelegate != address(0)) {
            votingPowers[currentDelegate].delegated = votingPowers[currentDelegate].delegated.sub(delegatorBalance);
        }

        if (delegatee != address(0)) {
            votingPowers[delegatee].delegated = votingPowers[delegatee].delegated.add(delegatorBalance);
        }

        emit DelegateChanged(delegator, currentDelegate, delegatee);
    }


    function getVotingPower(address account) public view returns (uint256) {
        uint256 balance = governanceToken.balanceOf(account);
        uint256 delegated = votingPowers[account].delegated;
        return balance.add(delegated);
    }


    function hasProposalThreshold(address account) public view returns (bool) {
        uint256 threshold = totalSupply.mul(PROPOSAL_THRESHOLD).div(100);
        return getVotingPower(account) >= threshold;
    }


    function isActiveProposal(uint256 proposalId) public view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime &&
               block.timestamp <= proposal.endTime &&
               !proposal.executed &&
               !proposal.canceled;
    }


    function isExecutableProposal(uint256 proposalId) public view returns (bool) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.executed || proposal.canceled) {
            return false;
        }

        if (block.timestamp < proposal.executionTime) {
            return false;
        }

        uint256 totalVotes = proposal.forVotes.add(proposal.againstVotes);
        uint256 quorum = totalSupply.mul(MINIMUM_QUORUM).div(100);

        return totalVotes >= quorum && proposal.forVotes > proposal.againstVotes;
    }


    function getProposal(uint256 proposalId) external view validProposal(proposalId) returns (
        uint256 id,
        address proposer,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 executionTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool canceled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.executionTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.canceled
        );
    }


    function getProposalOperations(uint256 proposalId) external view validProposal(proposalId) returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.calldatas);
    }


    function updateTotalSupply() external onlyOwner {
        totalSupply = governanceToken.totalSupply();
    }


    receive() external payable {}
}
