
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VotingGovernance is ReentrancyGuard, Ownable {
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    struct ProposalInfo {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
    }

    IERC20 public immutable governanceToken;

    uint256 public proposalCount;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant QUORUM_THRESHOLD = 10000 * 10**18;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => uint256) public lastVoteBlock;

    uint256[] public activeProposalIds;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votes
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed user, uint256 newPower);

    modifier onlyTokenHolder() {
        require(governanceToken.balanceOf(msg.sender) >= MIN_PROPOSAL_THRESHOLD, "Insufficient tokens");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }

    function updateVotingPower() external {
        uint256 balance = governanceToken.balanceOf(msg.sender);
        votingPower[msg.sender] = balance;
        emit VotingPowerUpdated(msg.sender, balance);
    }

    function createProposal(
        string memory _title,
        string memory _description
    ) external onlyTokenHolder nonReentrant returns (uint256) {
        require(bytes(_title).length > 0 && bytes(_title).length <= 100, "Invalid title length");
        require(bytes(_description).length > 0 && bytes(_description).length <= 1000, "Invalid description length");


        uint256 balance = governanceToken.balanceOf(msg.sender);
        require(balance >= MIN_PROPOSAL_THRESHOLD, "Insufficient voting power");
        votingPower[msg.sender] = balance;

        uint256 proposalId = ++proposalCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_DURATION;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;

        activeProposalIds.push(proposalId);

        emit ProposalCreated(proposalId, msg.sender, _title, startTime, endTime);

        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(!proposal.hasVoted[msg.sender], "Already voted");


        uint256 balance = governanceToken.balanceOf(msg.sender);
        require(balance > 0, "No voting power");
        votingPower[msg.sender] = balance;


        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;
        lastVoteBlock[msg.sender] = block.number;


        if (support) {
            proposal.forVotes += balance;
        } else {
            proposal.againstVotes += balance;
        }

        emit VoteCast(proposalId, msg.sender, support, balance);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");


        uint256 forVotes = proposal.forVotes;
        uint256 againstVotes = proposal.againstVotes;
        uint256 totalVotes = forVotes + againstVotes;

        require(totalVotes >= QUORUM_THRESHOLD, "Quorum not reached");
        require(forVotes > againstVotes, "Proposal rejected");

        proposal.executed = true;


        _removeFromActiveProposals(proposalId);

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized to cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;


        _removeFromActiveProposals(proposalId);

        emit ProposalCanceled(proposalId);
    }

    function getProposal(uint256 proposalId) external view validProposal(proposalId)
        returns (ProposalInfo memory) {
        Proposal storage proposal = proposals[proposalId];

        return ProposalInfo({
            id: proposal.id,
            proposer: proposal.proposer,
            title: proposal.title,
            description: proposal.description,
            forVotes: proposal.forVotes,
            againstVotes: proposal.againstVotes,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed,
            canceled: proposal.canceled
        });
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId)
        returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId)
        returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "User has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function getActiveProposals() external view returns (uint256[] memory) {
        return activeProposalIds;
    }

    function getActiveProposalCount() external view returns (uint256) {
        return activeProposalIds.length;
    }

    function isProposalActive(uint256 proposalId) external view validProposal(proposalId)
        returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime &&
               block.timestamp <= proposal.endTime &&
               !proposal.executed &&
               !proposal.canceled;
    }

    function getProposalStatus(uint256 proposalId) external view validProposal(proposalId)
        returns (string memory) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) return "Canceled";
        if (proposal.executed) return "Executed";
        if (block.timestamp < proposal.startTime) return "Pending";
        if (block.timestamp <= proposal.endTime) return "Active";

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        if (totalVotes < QUORUM_THRESHOLD) return "Failed (No Quorum)";
        if (proposal.forVotes <= proposal.againstVotes) return "Rejected";

        return "Succeeded";
    }

    function _removeFromActiveProposals(uint256 proposalId) internal {
        uint256 length = activeProposalIds.length;
        for (uint256 i = 0; i < length; i++) {
            if (activeProposalIds[i] == proposalId) {
                activeProposalIds[i] = activeProposalIds[length - 1];
                activeProposalIds.pop();
                break;
            }
        }
    }


    function emergencyPause() external onlyOwner {

    }

    function updateMinProposalThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0, "Invalid threshold");

    }
}
