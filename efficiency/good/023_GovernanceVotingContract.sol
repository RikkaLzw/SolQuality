
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GovernanceVotingContract is ReentrancyGuard, Ownable {

    struct Proposal {
        uint128 id;
        uint128 votingPower;
        uint64 startTime;
        uint64 endTime;
        uint32 forVotes;
        uint32 againstVotes;
        bool executed;
        bool cancelled;
        address proposer;
        string title;
        string description;
        bytes callData;
        address target;
    }

    struct Vote {
        bool hasVoted;
        bool support;
        uint96 weight;
    }


    IERC20 public immutable governanceToken;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant QUORUM_PERCENTAGE = 10;

    uint128 private _proposalCounter;
    uint128 private _totalSupply;


    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => uint256) public votingPower;
    mapping(address => uint256) public lastProposalTime;


    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed user, uint256 newPower);

    constructor(address _governanceToken) {
        governanceToken = IERC20(_governanceToken);
        _totalSupply = uint128(governanceToken.totalSupply());
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= _proposalCounter, "Invalid proposal");
        _;
    }

    modifier onlyDuringVoting(uint256 proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "Not in voting period");
        _;
    }

    function createProposal(
        string calldata title,
        string calldata description,
        address target,
        bytes calldata callData
    ) external returns (uint256) {

        uint256 userBalance = governanceToken.balanceOf(msg.sender);
        require(userBalance >= MIN_PROPOSAL_THRESHOLD, "Insufficient tokens");
        require(block.timestamp >= lastProposalTime[msg.sender] + 1 days, "Proposal cooldown");


        if (votingPower[msg.sender] != userBalance) {
            votingPower[msg.sender] = userBalance;
            emit VotingPowerUpdated(msg.sender, userBalance);
        }

        uint128 proposalId = ++_proposalCounter;


        proposals[proposalId] = Proposal({
            id: proposalId,
            votingPower: 0,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + VOTING_DURATION),
            forVotes: 0,
            againstVotes: 0,
            executed: false,
            cancelled: false,
            proposer: msg.sender,
            title: title,
            description: description,
            callData: callData,
            target: target
        });

        lastProposalTime[msg.sender] = block.timestamp;

        emit ProposalCreated(proposalId, msg.sender, title);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support)
        external
        validProposal(proposalId)
        onlyDuringVoting(proposalId)
    {
        Vote storage userVote = votes[proposalId][msg.sender];
        require(!userVote.hasVoted, "Already voted");


        uint256 userBalance = governanceToken.balanceOf(msg.sender);
        require(userBalance > 0, "No voting power");


        votingPower[msg.sender] = userBalance;


        Proposal memory proposal = proposals[proposalId];


        userVote.hasVoted = true;
        userVote.support = support;
        userVote.weight = uint96(userBalance);


        if (support) {
            proposals[proposalId].forVotes += uint32(userBalance / 10**18);
        } else {
            proposals[proposalId].againstVotes += uint32(userBalance / 10**18);
        }

        emit VoteCast(proposalId, msg.sender, support, userBalance);
    }

    function executeProposal(uint256 proposalId)
        external
        validProposal(proposalId)
        nonReentrant
    {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime + EXECUTION_DELAY, "Execution delay not met");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");


        uint32 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint32 requiredQuorum = uint32((_totalSupply / 10**18) * QUORUM_PERCENTAGE / 100);

        require(totalVotes >= requiredQuorum, "Quorum not met");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;


        if (proposal.target != address(0) && proposal.callData.length > 0) {
            (bool success,) = proposal.target.call(proposal.callData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId)
        external
        validProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer || msg.sender == owner(), "Not authorized");
        require(!proposal.executed, "Already executed");
        require(block.timestamp <= proposal.endTime, "Voting ended");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }


    function getProposalStatus(uint256 proposalId)
        external
        view
        validProposal(proposalId)
        returns (
            bool isActive,
            bool canExecute,
            bool hasQuorum,
            bool isPassing,
            uint256 forVotes,
            uint256 againstVotes
        )
    {
        Proposal memory proposal = proposals[proposalId];

        isActive = block.timestamp >= proposal.startTime &&
                  block.timestamp <= proposal.endTime &&
                  !proposal.cancelled;

        uint32 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint32 requiredQuorum = uint32((_totalSupply / 10**18) * QUORUM_PERCENTAGE / 100);

        hasQuorum = totalVotes >= requiredQuorum;
        isPassing = proposal.forVotes > proposal.againstVotes;
        canExecute = !proposal.executed &&
                    !proposal.cancelled &&
                    block.timestamp > proposal.endTime + EXECUTION_DELAY &&
                    hasQuorum &&
                    isPassing;

        forVotes = uint256(proposal.forVotes) * 10**18;
        againstVotes = uint256(proposal.againstVotes) * 10**18;
    }

    function getUserVote(uint256 proposalId, address user)
        external
        view
        returns (bool hasVoted, bool support, uint256 weight)
    {
        Vote memory userVote = votes[proposalId][user];
        return (userVote.hasVoted, userVote.support, uint256(userVote.weight));
    }

    function getProposalCount() external view returns (uint256) {
        return _proposalCounter;
    }

    function updateVotingPower(address user) external {
        uint256 currentBalance = governanceToken.balanceOf(user);
        votingPower[user] = currentBalance;
        emit VotingPowerUpdated(user, currentBalance);
    }


    function emergencyPause() external onlyOwner {

    }

    function updateTotalSupply() external onlyOwner {
        _totalSupply = uint128(governanceToken.totalSupply());
    }
}
