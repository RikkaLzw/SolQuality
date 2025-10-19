
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract DAOGovernanceContract is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public constant PROPOSAL_THRESHOLD = 100;
    uint256 public constant MAX_OPERATIONS = 10;


    IERC20 public immutable governanceToken;


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
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        uint256 eta;
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


    uint256 private _proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    mapping(bytes32 => bool) public queuedTransactions;


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
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);


    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= _proposalCount, "Invalid proposal ID");
        _;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        require(state(proposalId) == ProposalState.Active, "Proposal not active");
        _;
    }

    modifier onlyProposer(uint256 proposalId) {
        require(msg.sender == proposals[proposalId].proposer, "Not proposer");
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
        require(targets.length > 0, "Must provide actions");
        require(targets.length <= MAX_OPERATIONS, "Too many operations");
        require(
            targets.length == values.length && targets.length == calldatas.length,
            "Proposal function information arity mismatch"
        );

        uint256 proposalId = ++_proposalCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime.add(VOTING_PERIOD);

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;
        newProposal.description = description;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;

        emit ProposalCreated(
            proposalId,
            msg.sender,
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

        uint256 votes = governanceToken.balanceOf(voter);
        require(votes > 0, "No voting power");

        Proposal storage proposal = proposals[proposalId];

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes.add(votes);
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes.add(votes);
        } else {
            proposal.abstainVotes = proposal.abstainVotes.add(votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes, reason);
    }


    function queue(uint256 proposalId) external onlyValidProposal(proposalId) {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");

        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp.add(EXECUTION_DELAY);
        proposal.eta = eta;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash = keccak256(
                abi.encode(
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.calldatas[i],
                    eta
                )
            );
            queuedTransactions[txHash] = true;
        }

        emit ProposalQueued(proposalId, eta);
    }


    function execute(uint256 proposalId) external payable nonReentrant onlyValidProposal(proposalId) {
        require(state(proposalId) == ProposalState.Queued, "Proposal not queued");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.eta, "Execution time not reached");
        require(block.timestamp <= proposal.eta.add(EXECUTION_DELAY), "Execution window expired");

        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash = keccak256(
                abi.encode(
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.calldatas[i],
                    proposal.eta
                )
            );
            require(queuedTransactions[txHash], "Transaction not queued");
            queuedTransactions[txHash] = false;

            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                proposal.calldatas[i]
            );
            require(success, "Transaction execution reverted");
        }

        emit ProposalExecuted(proposalId);
    }


    function cancel(uint256 proposalId) external onlyValidProposal(proposalId) {
        ProposalState currentState = state(proposalId);
        require(
            currentState != ProposalState.Executed && currentState != ProposalState.Canceled,
            "Cannot cancel"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized to cancel"
        );

        proposal.canceled = true;


        if (currentState == ProposalState.Queued) {
            for (uint256 i = 0; i < proposal.targets.length; i++) {
                bytes32 txHash = keccak256(
                    abi.encode(
                        proposal.targets[i],
                        proposal.values[i],
                        proposal.calldatas[i],
                        proposal.eta
                    )
                );
                queuedTransactions[txHash] = false;
            }
        }

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
            if (proposal.eta == 0) {
                return ProposalState.Succeeded;
            } else if (block.timestamp >= proposal.eta.add(EXECUTION_DELAY)) {
                return ProposalState.Expired;
            } else {
                return ProposalState.Queued;
            }
        } else {
            return ProposalState.Defeated;
        }
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


    function getProposal(uint256 proposalId) external view onlyValidProposal(proposalId) returns (
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool canceled,
        bool executed,
        string memory description
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
            proposal.executed,
            proposal.description
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


    function proposalCount() external view returns (uint256) {
        return _proposalCount;
    }


    receive() external payable {}


    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
