
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract DAOGovernance is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public constant VOTING_POWER_DIVISOR = 10**18;


    IERC20 public immutable governanceToken;


    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Queued,
        Executed,
        Cancelled
    }


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
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        mapping(address => Receipt) receipts;
    }


    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
    }


    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public latestProposalIds;
    uint256 public proposalCount;
    uint256 public executionDelay = EXECUTION_DELAY;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    event ProposalQueued(uint256 indexed proposalId, uint256 executionTime);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);


    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        require(getProposalState(proposalId) == ProposalState.Active, "Proposal not active");
        _;
    }

    modifier onlySucceededProposal(uint256 proposalId) {
        require(getProposalState(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        _;
    }

    modifier onlyQueuedProposal(uint256 proposalId) {
        require(getProposalState(proposalId) == ProposalState.Queued, "Proposal not queued");
        _;
    }

    modifier hasVotingPower(address account) {
        require(governanceToken.balanceOf(account) > 0, "No voting power");
        _;
    }

    modifier meetsProposalThreshold(address proposer) {
        require(
            governanceToken.balanceOf(proposer) >= PROPOSAL_THRESHOLD,
            "Insufficient tokens to create proposal"
        );
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }


    function propose(
        string memory title,
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external meetsProposalThreshold(msg.sender) nonReentrant returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(targets.length > 0, "Must provide at least one target");
        require(
            targets.length == values.length && targets.length == calldatas.length,
            "Proposal function information arity mismatch"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = getProposalState(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "One live proposal per proposer"
            );
        }

        proposalCount++;
        uint256 newProposalId = proposalCount;

        Proposal storage newProposal = proposals[newProposalId];
        newProposal.id = newProposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp.add(VOTING_PERIOD);

        latestProposalIds[msg.sender] = newProposalId;

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            title,
            targets,
            values,
            calldatas,
            newProposal.startTime,
            newProposal.endTime
        );

        return newProposalId;
    }


    function castVote(
        uint256 proposalId,
        uint8 support
    ) external onlyValidProposal(proposalId) onlyActiveProposal(proposalId) hasVotingPower(msg.sender) {
        return _castVote(msg.sender, proposalId, support, "");
    }


    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external onlyValidProposal(proposalId) onlyActiveProposal(proposalId) hasVotingPower(msg.sender) {
        return _castVote(msg.sender, proposalId, support, reason);
    }


    function queue(uint256 proposalId) external onlyValidProposal(proposalId) onlySucceededProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        uint256 executionTime = block.timestamp.add(executionDelay);

        emit ProposalQueued(proposalId, executionTime);
    }


    function execute(uint256 proposalId) external payable onlyValidProposal(proposalId) onlyQueuedProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(
            block.timestamp >= proposal.endTime.add(executionDelay),
            "Execution delay not met"
        );

        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(proposal.targets[i], proposal.values[i], proposal.calldatas[i]);
        }

        emit ProposalExecuted(proposalId);
    }


    function cancel(uint256 proposalId) external onlyValidProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Only proposer or owner can cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }


    function getProposalState(uint256 proposalId) public view onlyValidProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            if (block.timestamp >= proposal.endTime.add(executionDelay)) {
                return ProposalState.Queued;
            } else {
                return ProposalState.Succeeded;
            }
        } else {
            return ProposalState.Defeated;
        }
    }


    function getProposal(uint256 proposalId) external view onlyValidProposal(proposalId) returns (
        uint256 id,
        address proposer,
        string memory title,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool cancelled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.cancelled
        );
    }


    function getProposalActions(uint256 proposalId) external view onlyValidProposal(proposalId) returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.calldatas);
    }


    function getReceipt(uint256 proposalId, address voter) external view onlyValidProposal(proposalId) returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }


    function _castVote(address voter, uint256 proposalId, uint8 support, string memory reason) internal {
        require(support <= 2, "Invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(!receipt.hasVoted, "Voter already voted");

        uint256 votes = governanceToken.balanceOf(voter);
        require(votes > 0, "No voting power");

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes.add(votes);
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes.add(votes);
        } else {
            proposal.abstainVotes = proposal.abstainVotes.add(votes);
        }

        emit VoteCast(voter, proposalId, support, votes, reason);
    }


    function _executeTransaction(address target, uint256 value, bytes memory data) internal {
        require(address(this).balance >= value, "Insufficient contract balance");

        (bool success, ) = target.call{value: value}(data);
        require(success, "Transaction execution failed");
    }


    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes.add(proposal.againstVotes).add(proposal.abstainVotes);
        uint256 quorum = governanceToken.totalSupply().mul(QUORUM_PERCENTAGE).div(100);
        return totalVotes >= quorum;
    }


    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }


    function updateExecutionDelay(uint256 newDelay) external onlyOwner {
        require(newDelay >= 1 days && newDelay <= 30 days, "Invalid delay period");
        executionDelay = newDelay;
    }


    receive() external payable {}


    fallback() external payable {}
}
