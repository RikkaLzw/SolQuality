
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DAOGovernanceContract is Ownable, ReentrancyGuard {

    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 20;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant MAX_OPERATIONS = 10;


    IERC20 public immutable governanceToken;


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
        bool canceled;
        mapping(address => Receipt) receipts;
    }


    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
    }


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


    mapping(uint256 => Proposal) private proposals;
    mapping(bytes32 => bool) private queuedTransactions;
    uint256 private proposalCount;
    uint256 public totalSupply;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);


    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        require(state(proposalId) == ProposalState.Active, "Proposal not active");
        _;
    }

    modifier onlyProposer(uint256 proposalId) {
        require(
            msg.sender == proposals[proposalId].proposer || msg.sender == owner(),
            "Not authorized"
        );
        _;
    }

    modifier sufficientBalance(address account, uint256 amount) {
        require(governanceToken.balanceOf(account) >= amount, "Insufficient token balance");
        _;
    }


    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
        totalSupply = governanceToken.totalSupply();
    }


    function propose(
        string memory title,
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external sufficientBalance(msg.sender, PROPOSAL_THRESHOLD) returns (uint256) {
        require(targets.length == values.length && targets.length == calldatas.length,
                "Proposal function information mismatch");
        require(targets.length > 0 && targets.length <= MAX_OPERATIONS,
                "Invalid number of operations");
        require(bytes(title).length > 0, "Title cannot be empty");

        proposalCount++;
        uint256 proposalId = proposalCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;

        emit ProposalCreated(proposalId, msg.sender, title, description, startTime, endTime);
        return proposalId;
    }


    function castVote(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external onlyValidProposal(proposalId) onlyActiveProposal(proposalId) {
        return _castVote(proposalId, msg.sender, support, reason);
    }


    function _castVote(
        uint256 proposalId,
        address voter,
        uint8 support,
        string memory reason
    ) internal {
        require(support <= 2, "Invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];

        require(!receipt.hasVoted, "Already voted");

        uint256 weight = governanceToken.balanceOf(voter);
        require(weight > 0, "No voting power");

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = weight;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(voter, proposalId, support, weight, reason);
    }


    function queue(uint256 proposalId) external onlyValidProposal(proposalId) {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");

        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + EXECUTION_DELAY;

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


    function execute(uint256 proposalId)
        external
        payable
        nonReentrant
        onlyValidProposal(proposalId)
    {
        require(state(proposalId) == ProposalState.Queued, "Proposal not queued");

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash = keccak256(
                abi.encode(
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.calldatas[i],
                    block.timestamp
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


    function cancel(uint256 proposalId)
        external
        onlyValidProposal(proposalId)
        onlyProposer(proposalId)
    {
        ProposalState currentState = state(proposalId);
        require(
            currentState != ProposalState.Executed && currentState != ProposalState.Canceled,
            "Cannot cancel proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }


    function state(uint256 proposalId) public view onlyValidProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp <= proposal.startTime) {
            return ProposalState.Pending;
        } else if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        } else if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }


    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        return (totalVotes * 100) >= (totalSupply * QUORUM_PERCENTAGE);
    }


    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }


    function getProposal(uint256 proposalId)
        external
        view
        onlyValidProposal(proposalId)
        returns (
            address proposer,
            string memory title,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool executed,
            bool canceled
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.canceled
        );
    }


    function getReceipt(uint256 proposalId, address voter)
        external
        view
        onlyValidProposal(proposalId)
        returns (bool hasVoted, uint8 support, uint256 votes)
    {
        Receipt storage receipt = proposals[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.support, receipt.votes);
    }


    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }


    receive() external payable {}
}
