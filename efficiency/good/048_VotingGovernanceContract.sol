
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract VotingGovernanceContract is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    struct Proposal {
        uint128 id;
        uint128 votingEndTime;
        address proposer;
        uint96 forVotes;
        uint96 againstVotes;
        uint32 abstainVotes;
        bool executed;
        bool canceled;
        string description;
        bytes callData;
        address target;
    }


    struct VoteRecord {
        uint8 support;
        uint96 weight;
        bool hasVoted;
    }

    Counters.Counter private _proposalIds;


    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant PROPOSAL_THRESHOLD = 100000e18;
    uint256 public constant QUORUM_PERCENTAGE = 4;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => VoteRecord)) public votes;
    mapping(address => uint256) public votingPower;
    mapping(address => uint256) private _delegatedPower;
    mapping(address => address) public delegates;

    uint256 public totalVotingPower;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address target,
        string description,
        uint256 votingStartTime,
        uint256 votingEndTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newPower);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId <= _proposalIds.current() && proposalId > 0, "Invalid proposal");
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }

    function createProposal(
        address target,
        bytes memory callData,
        string memory description
    ) external returns (uint256) {
        require(getVotes(msg.sender) >= PROPOSAL_THRESHOLD, "Insufficient voting power");
        require(bytes(description).length > 0, "Empty description");

        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();


        uint256 currentTime = block.timestamp;
        uint256 votingEndTime = currentTime + VOTING_PERIOD + VOTING_DELAY;


        Proposal memory newProposal = Proposal({
            id: uint128(proposalId),
            votingEndTime: uint128(votingEndTime),
            proposer: msg.sender,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false,
            description: description,
            callData: callData,
            target: target
        });

        proposals[proposalId] = newProposal;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            target,
            description,
            currentTime + VOTING_DELAY,
            votingEndTime
        );

        return proposalId;
    }

    function castVote(uint256 proposalId, uint8 support) external onlyValidProposal(proposalId) {
        return _castVote(proposalId, msg.sender, support);
    }

    function _castVote(uint256 proposalId, address voter, uint8 support) internal {
        require(support <= 2, "Invalid vote type");


        Proposal memory proposal = proposals[proposalId];
        require(block.timestamp >= (proposal.votingEndTime - VOTING_PERIOD), "Voting not started");
        require(block.timestamp <= proposal.votingEndTime, "Voting ended");
        require(!proposal.executed, "Proposal executed");
        require(!proposal.canceled, "Proposal canceled");

        VoteRecord storage voteRecord = votes[proposalId][voter];
        require(!voteRecord.hasVoted, "Already voted");

        uint256 weight = getVotes(voter);
        require(weight > 0, "No voting power");

        voteRecord.hasVoted = true;
        voteRecord.support = support;
        voteRecord.weight = uint96(weight);


        if (support == 0) {
            proposals[proposalId].againstVotes += uint96(weight);
        } else if (support == 1) {
            proposals[proposalId].forVotes += uint96(weight);
        } else {
            proposals[proposalId].abstainVotes += uint32(weight);
        }

        emit VoteCast(voter, proposalId, support, weight);
    }

    function executeProposal(uint256 proposalId) external nonReentrant onlyValidProposal(proposalId) {

        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.votingEndTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");


        uint256 forVotes = proposal.forVotes;
        uint256 againstVotes = proposal.againstVotes;
        uint256 abstainVotes = proposal.abstainVotes;
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;


        uint256 quorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;
        require(totalVotes >= quorum, "Quorum not reached");
        require(forVotes > againstVotes, "Proposal rejected");

        proposal.executed = true;


        if (proposal.target != address(0)) {
            (bool success, ) = proposal.target.call(proposal.callData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external onlyValidProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Unauthorized"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender];
        delegates[msg.sender] = delegatee;

        uint256 delegatorPower = votingPower[msg.sender];


        if (currentDelegate != address(0) && currentDelegate != delegatee) {
            _delegatedPower[currentDelegate] -= delegatorPower;
        }

        if (delegatee != address(0) && delegatee != currentDelegate) {
            _delegatedPower[delegatee] += delegatorPower;
        }

        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
    }

    function setVotingPower(address account, uint256 power) external onlyOwner {
        uint256 oldPower = votingPower[account];
        votingPower[account] = power;


        if (power > oldPower) {
            totalVotingPower += (power - oldPower);
        } else {
            totalVotingPower -= (oldPower - power);
        }


        address delegatee = delegates[account];
        if (delegatee != address(0)) {
            if (power > oldPower) {
                _delegatedPower[delegatee] += (power - oldPower);
            } else {
                _delegatedPower[delegatee] -= (oldPower - power);
            }
        }

        emit VotingPowerUpdated(account, power);
    }

    function getVotes(address account) public view returns (uint256) {
        return votingPower[account] + _delegatedPower[account];
    }

    function getProposalState(uint256 proposalId) external view onlyValidProposal(proposalId) returns (uint8) {
        Proposal memory proposal = proposals[proposalId];

        if (proposal.canceled) return 2;
        if (proposal.executed) return 7;

        uint256 currentTime = block.timestamp;
        if (currentTime <= (proposal.votingEndTime - VOTING_PERIOD)) return 0;
        if (currentTime <= proposal.votingEndTime) return 1;


        uint256 forVotes = proposal.forVotes;
        uint256 againstVotes = proposal.againstVotes;
        uint256 totalVotes = forVotes + againstVotes + proposal.abstainVotes;
        uint256 quorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        if (totalVotes < quorum) return 3;
        if (forVotes <= againstVotes) return 4;

        return 5;
    }

    function getProposalVotes(uint256 proposalId) external view onlyValidProposal(proposalId) returns (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes, proposal.abstainVotes);
    }

    function hasVoted(uint256 proposalId, address account) external view returns (bool) {
        return votes[proposalId][account].hasVoted;
    }

    function proposalCount() external view returns (uint256) {
        return _proposalIds.current();
    }
}
