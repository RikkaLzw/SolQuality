
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract DAOGovernanceContract is Ownable, ReentrancyGuard {
    using SafeMath for uint256;


    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
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
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool canceled;
        bool executed;
        string description;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
    }


    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 votes;
    }


    uint256 private _proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    mapping(address => uint256) public latestProposalIds;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 votes
    );

    event ProposalQueued(uint256 indexed proposalId, uint256 executionTime);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);


    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= _proposalCount, "Invalid proposal ID");
        _;
    }

    modifier onlyProposer(uint256 proposalId) {
        require(proposals[proposalId].proposer == msg.sender, "Not the proposer");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposals[proposalId].id != 0, "Proposal does not exist");
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }


    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(
            governanceToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD,
            "Insufficient tokens to create proposal"
        );
        require(targets.length > 0, "Must provide actions");
        require(targets.length <= MAX_OPERATIONS, "Too many operations");
        require(
            targets.length == values.length &&
            targets.length == signatures.length &&
            targets.length == calldatas.length,
            "Proposal function information arity mismatch"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposerLatestProposalState = state(latestProposalId);
            require(
                proposerLatestProposalState != ProposalState.Active,
                "One live proposal per proposer"
            );
        }

        uint256 proposalId = ++_proposalCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime.add(VOTING_PERIOD);

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            startTime: startTime,
            endTime: endTime,
            executionTime: 0,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false,
            description: description,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas
        });

        latestProposalIds[msg.sender] = proposalId;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            startTime,
            endTime
        );

        return proposalId;
    }


    function castVote(uint256 proposalId, bool support) external validProposal(proposalId) {
        require(state(proposalId) == ProposalState.Active, "Voting is closed");

        Receipt storage receipt = receipts[proposalId][msg.sender];
        require(!receipt.hasVoted, "Voter already voted");

        uint256 votes = governanceToken.balanceOf(msg.sender);
        require(votes > 0, "No voting power");

        if (support) {
            proposals[proposalId].forVotes = proposals[proposalId].forVotes.add(votes);
        } else {
            proposals[proposalId].againstVotes = proposals[proposalId].againstVotes.add(votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(msg.sender, proposalId, support, votes);
    }


    function queue(uint256 proposalId) external validProposal(proposalId) {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal cannot be queued");

        uint256 executionTime = block.timestamp.add(EXECUTION_DELAY);
        proposals[proposalId].executionTime = executionTime;

        emit ProposalQueued(proposalId, executionTime);
    }


    function execute(uint256 proposalId) external payable nonReentrant validProposal(proposalId) {
        require(state(proposalId) == ProposalState.Queued, "Proposal cannot be executed");
        require(block.timestamp >= proposals[proposalId].executionTime, "Execution time not reached");

        proposals[proposalId].executed = true;

        Proposal storage proposal = proposals[proposalId];
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i]
            );
        }

        emit ProposalExecuted(proposalId);
    }


    function cancel(uint256 proposalId) external validProposal(proposalId) {
        ProposalState currentState = state(proposalId);
        require(
            currentState == ProposalState.Pending ||
            currentState == ProposalState.Active ||
            currentState == ProposalState.Queued,
            "Cannot cancel proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer ||
            msg.sender == owner() ||
            governanceToken.balanceOf(proposal.proposer) < PROPOSAL_THRESHOLD,
            "Unauthorized to cancel"
        );

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }


    function state(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || !_quorumReached(proposalId)) {
            return ProposalState.Defeated;
        } else if (proposal.executionTime == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.executionTime.add(EXECUTION_DELAY)) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }


    function getProposal(uint256 proposalId) external view validProposal(proposalId) returns (
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
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
            proposal.canceled,
            proposal.executed,
            proposal.description
        );
    }


    function getActions(uint256 proposalId) external view validProposal(proposalId) returns (
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.signatures, proposal.calldatas);
    }


    function proposalCount() external view returns (uint256) {
        return _proposalCount;
    }


    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        uint256 totalVotes = proposals[proposalId].forVotes.add(proposals[proposalId].againstVotes);
        uint256 totalSupply = governanceToken.totalSupply();
        return totalVotes.mul(100).div(totalSupply) >= QUORUM_PERCENTAGE;
    }


    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) internal {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, ) = target.call{value: value}(callData);
        require(success, "Transaction execution reverted");
    }


    receive() external payable {}


    fallback() external payable {}
}
