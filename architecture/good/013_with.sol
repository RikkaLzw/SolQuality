
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract DAOGovernanceContract is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;


    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant MAX_OPERATIONS = 10;


    IERC20 public immutable governanceToken;


    Counters.Counter private _proposalIds;


    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }


    struct Proposal {
        uint256 id;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
    }


    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
    }


    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    mapping(address => uint256) public latestProposalIds;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startTime,
        uint256 endTime,
        string description
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 executionTime);
    event ProposalExecuted(uint256 indexed proposalId);


    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= _proposalIds.current(), "Invalid proposal ID");
        _;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        require(state(proposalId) == ProposalState.Active, "Proposal not active");
        _;
    }

    modifier onlyProposer(uint256 proposalId) {
        require(proposals[proposalId].proposer == msg.sender, "Not proposer");
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }


    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(
            governanceToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD,
            "Insufficient tokens to propose"
        );
        require(targets.length > 0, "Must provide targets");
        require(targets.length <= MAX_OPERATIONS, "Too many operations");
        require(
            targets.length == values.length && targets.length == calldatas.length,
            "Proposal function information mismatch"
        );

        address proposer = msg.sender;
        uint256 latestProposalId = latestProposalIds[proposer];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "One live proposal per proposer"
            );
        }

        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: proposer,
            startTime: startTime,
            endTime: endTime,
            executionTime: 0,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            canceled: false,
            executed: false,
            description: description,
            targets: targets,
            values: values,
            calldatas: calldatas
        });

        latestProposalIds[proposer] = proposalId;

        emit ProposalCreated(
            proposalId,
            proposer,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            startTime,
            endTime,
            description
        );

        return proposalId;
    }


    function castVote(uint256 proposalId, uint8 support) external {
        return _castVote(msg.sender, proposalId, support, "");
    }


    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        return _castVote(msg.sender, proposalId, support, reason);
    }


    function _castVote(
        address voter,
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) internal onlyValidProposal(proposalId) onlyActiveProposal(proposalId) {
        require(support <= 2, "Invalid vote type");

        Receipt storage receipt = receipts[proposalId][voter];
        require(!receipt.hasVoted, "Already voted");

        uint256 votes = _getVotingPower(voter, proposals[proposalId].startTime);
        require(votes > 0, "No voting power");

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        Proposal storage proposal = proposals[proposalId];
        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        emit VoteCast(voter, proposalId, support, votes, reason);
    }


    function queue(uint256 proposalId) external onlyValidProposal(proposalId) {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");

        uint256 executionTime = block.timestamp + EXECUTION_DELAY;
        proposals[proposalId].executionTime = executionTime;

        emit ProposalQueued(proposalId, executionTime);
    }


    function execute(uint256 proposalId) external payable nonReentrant onlyValidProposal(proposalId) {
        require(state(proposalId) == ProposalState.Queued, "Proposal not queued");

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(proposal.targets[i], proposal.values[i], proposal.calldatas[i]);
        }

        emit ProposalExecuted(proposalId);
    }


    function cancel(uint256 proposalId) external onlyValidProposal(proposalId) {
        ProposalState currentState = state(proposalId);
        require(
            currentState == ProposalState.Pending || currentState == ProposalState.Active,
            "Cannot cancel proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer ||
            msg.sender == owner() ||
            governanceToken.balanceOf(proposal.proposer) < PROPOSAL_THRESHOLD,
            "Not authorized to cancel"
        );

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }


    function state(uint256 proposalId) public view onlyValidProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        } else if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            if (proposal.executionTime == 0) {
                return ProposalState.Succeeded;
            } else if (block.timestamp >= proposal.executionTime + EXECUTION_DELAY) {
                return ProposalState.Expired;
            } else {
                return ProposalState.Queued;
            }
        } else {
            return ProposalState.Defeated;
        }
    }


    function getProposal(uint256 proposalId) external view onlyValidProposal(proposalId) returns (
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool canceled,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.canceled,
            proposal.executed
        );
    }


    function getActions(uint256 proposalId) external view onlyValidProposal(proposalId) returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.calldatas);
    }


    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return receipts[proposalId][voter];
    }


    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorum = (governanceToken.totalSupply() * QUORUM_PERCENTAGE) / 100;
        return totalVotes >= quorum;
    }


    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }


    function _getVotingPower(address account, uint256 timestamp) internal view returns (uint256) {

        return governanceToken.balanceOf(account);
    }


    function _executeTransaction(address target, uint256 value, bytes memory data) internal {
        require(target != address(0), "Invalid target");

        (bool success, ) = target.call{value: value}(data);
        require(success, "Transaction execution reverted");
    }


    function proposalCount() external view returns (uint256) {
        return _proposalIds.current();
    }


    receive() external payable {}


    fallback() external payable {}
}
