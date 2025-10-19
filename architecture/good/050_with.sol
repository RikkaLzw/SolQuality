
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract DAOGovernanceContract is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 20;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant MAX_OPERATIONS = 10;


    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Canceled
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }


    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        VoteType vote;
        uint256 votes;
    }


    IERC20 public immutable governanceToken;
    Counters.Counter private _proposalIds;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public latestProposalIds;

    uint256 public totalSupply;


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
        VoteType vote,
        uint256 votes
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);


    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= _proposalIds.current(), "Invalid proposal ID");
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

    modifier hasVotingPower(address account) {
        require(getVotingPower(account) > 0, "No voting power");
        _;
    }

    modifier validOperations(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) {
        require(
            targets.length == values.length && targets.length == calldatas.length,
            "Proposal function information mismatch"
        );
        require(targets.length > 0 && targets.length <= MAX_OPERATIONS, "Invalid operations count");
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
        totalSupply = governanceToken.totalSupply();
    }


    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        external
        validOperations(targets, values, calldatas)
        returns (uint256)
    {
        require(
            getVotingPower(msg.sender) >= PROPOSAL_THRESHOLD,
            "Insufficient tokens to propose"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = getProposalState(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "One live proposal per proposer"
            );
        }

        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_DURATION;
        newProposal.executionTime = newProposal.endTime + EXECUTION_DELAY;

        latestProposalIds[msg.sender] = proposalId;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            newProposal.startTime,
            newProposal.endTime
        );

        return proposalId;
    }


    function castVote(uint256 proposalId, VoteType vote)
        external
        onlyValidProposal(proposalId)
        onlyActiveProposal(proposalId)
        hasVotingPower(msg.sender)
    {
        _castVote(msg.sender, proposalId, vote);
    }


    function execute(uint256 proposalId)
        external
        payable
        nonReentrant
        onlyValidProposal(proposalId)
        onlySucceededProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.executionTime, "Execution delay not met");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeOperation(
                proposal.targets[i],
                proposal.values[i],
                proposal.calldatas[i]
            );
        }

        emit ProposalExecuted(proposalId);
    }


    function cancel(uint256 proposalId)
        external
        onlyValidProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        require(
            msg.sender == owner() ||
            msg.sender == proposal.proposer ||
            getVotingPower(proposal.proposer) < PROPOSAL_THRESHOLD,
            "Not authorized to cancel"
        );

        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }


    function getProposalState(uint256 proposalId)
        public
        view
        onlyValidProposal(proposalId)
        returns (ProposalState)
    {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        }

        return ProposalState.Defeated;
    }


    function getVotingPower(address account) public view returns (uint256) {
        return governanceToken.balanceOf(account);
    }


    function getProposal(uint256 proposalId)
        external
        view
        onlyValidProposal(proposalId)
        returns (
            address proposer,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            uint256 executionTime,
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
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.executionTime,
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
        returns (bool hasVoted, VoteType vote, uint256 votes)
    {
        Receipt storage receipt = proposals[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.vote, receipt.votes);
    }


    function proposalCount() external view returns (uint256) {
        return _proposalIds.current();
    }


    function _castVote(address voter, uint256 proposalId, VoteType vote) internal {
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];

        require(!receipt.hasVoted, "Voter already voted");

        uint256 votes = getVotingPower(voter);
        require(votes > 0, "No voting power");

        receipt.hasVoted = true;
        receipt.vote = vote;
        receipt.votes = votes;

        if (vote == VoteType.For) {
            proposal.forVotes += votes;
        } else if (vote == VoteType.Against) {
            proposal.againstVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        emit VoteCast(voter, proposalId, vote, votes);
    }

    function _executeOperation(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (bool success, ) = target.call{value: value}(data);
        require(success, "Execution failed");
    }

    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        return totalVotes >= (totalSupply * QUORUM_PERCENTAGE) / 100;
    }

    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }


    receive() external payable {}
}
