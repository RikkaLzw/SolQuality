
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract VotingGovernanceContract is Ownable, ReentrancyGuard {

    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public constant PROPOSAL_THRESHOLD = 100;


    IERC20 public immutable governanceToken;


    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Cancelled
    }


    enum VoteType {
        Against,
        For,
        Abstain
    }


    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => VoteType) votes;
    }


    uint256 private _proposalCounter;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;


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
        VoteType voteType,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newPower);


    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= _proposalCounter, "Invalid proposal ID");
        _;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        require(getProposalState(proposalId) == ProposalState.Active, "Proposal not active");
        _;
    }

    modifier hasNotVoted(uint256 proposalId) {
        require(!proposals[proposalId].hasVoted[msg.sender], "Already voted");
        _;
    }

    modifier hasVotingPower() {
        require(getVotingPower(msg.sender) > 0, "No voting power");
        _;
    }

    modifier canCreateProposal() {
        require(
            getVotingPower(msg.sender) >= PROPOSAL_THRESHOLD,
            "Insufficient tokens to create proposal"
        );
        _;
    }


    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }


    function createProposal(
        string calldata title,
        string calldata description
    ) external canCreateProposal returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        _proposalCounter++;
        uint256 proposalId = _proposalCounter;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_DURATION;
        newProposal.executionTime = newProposal.endTime + EXECUTION_DELAY;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            newProposal.startTime,
            newProposal.endTime
        );

        return proposalId;
    }


    function castVote(
        uint256 proposalId,
        VoteType voteType
    ) external validProposal(proposalId) onlyActiveProposal(proposalId) hasNotVoted(proposalId) hasVotingPower {
        uint256 weight = getVotingPower(msg.sender);

        Proposal storage proposal = proposals[proposalId];
        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = voteType;

        _updateVoteCount(proposal, voteType, weight);

        emit VoteCast(msg.sender, proposalId, voteType, weight);
    }


    function executeProposal(uint256 proposalId) external validProposal(proposalId) nonReentrant {
        require(getProposalState(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        require(block.timestamp >= proposals[proposalId].executionTime, "Execution delay not met");

        proposals[proposalId].executed = true;

        emit ProposalExecuted(proposalId);
    }


    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == owner() || msg.sender == proposal.proposer,
            "Not authorized to cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }


    function updateVotingPower(address account, uint256 power) external onlyOwner {
        require(account != address(0), "Invalid account");
        votingPower[account] = power;

        emit VotingPowerUpdated(account, power);
    }


    function batchUpdateVotingPower(
        address[] calldata accounts,
        uint256[] calldata powers
    ) external onlyOwner {
        require(accounts.length == powers.length, "Arrays length mismatch");

        for (uint256 i = 0; i < accounts.length; i++) {
            _updateSingleVotingPower(accounts[i], powers[i]);
        }
    }


    function getProposalState(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        return _determineEndState(proposal);
    }


    function getVotingPower(address account) public view returns (uint256) {
        uint256 manualPower = votingPower[account];
        uint256 tokenBalance = governanceToken.balanceOf(account);

        return manualPower > tokenBalance ? manualPower : tokenBalance;
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
        uint256 abstainVotes,
        bool executed,
        bool cancelled
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
            proposal.abstainVotes,
            proposal.executed,
            proposal.cancelled
        );
    }


    function hasVoted(uint256 proposalId, address account) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[account];
    }


    function getVote(uint256 proposalId, address account) external view validProposal(proposalId) returns (VoteType) {
        require(proposals[proposalId].hasVoted[account], "Account has not voted");
        return proposals[proposalId].votes[account];
    }


    function getProposalCount() external view returns (uint256) {
        return _proposalCounter;
    }


    function getQuorum() public view returns (uint256) {
        return (governanceToken.totalSupply() * QUORUM_PERCENTAGE) / 100;
    }




    function _updateVoteCount(Proposal storage proposal, VoteType voteType, uint256 weight) internal {
        if (voteType == VoteType.For) {
            proposal.forVotes += weight;
        } else if (voteType == VoteType.Against) {
            proposal.againstVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }
    }


    function _determineEndState(Proposal storage proposal) internal view returns (ProposalState) {
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorum = getQuorum();

        if (totalVotes < quorum) {
            return ProposalState.Defeated;
        }

        if (proposal.forVotes > proposal.againstVotes) {
            return ProposalState.Succeeded;
        }

        return ProposalState.Defeated;
    }


    function _updateSingleVotingPower(address account, uint256 power) internal {
        require(account != address(0), "Invalid account");
        votingPower[account] = power;

        emit VotingPowerUpdated(account, power);
    }
}
