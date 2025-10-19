
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOGovernanceContract is ReentrancyGuard, Ownable {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterWeight;
    }

    struct ProposalInfo {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }

    IERC20 public immutable governanceToken;

    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18;
    uint256 public constant QUORUM_PERCENTAGE = 10;

    uint256 public proposalCount;
    uint256 private totalSupplyCache;
    uint256 private lastCacheUpdate;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public lastProposalTime;
    mapping(address => uint256[]) private userProposals;

    uint256[] public activeProposals;
    mapping(uint256 => uint256) private activeProposalIndex;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);

    constructor(address _governanceToken) {
        governanceToken = IERC20(_governanceToken);
        totalSupplyCache = governanceToken.totalSupply();
        lastCacheUpdate = block.timestamp;
    }

    function createProposal(string calldata description) external nonReentrant {
        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance >= MIN_PROPOSAL_THRESHOLD, "Insufficient tokens");
        require(
            block.timestamp >= lastProposalTime[msg.sender] + 1 days,
            "Proposal cooldown"
        );

        uint256 proposalId = ++proposalCount;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_DURATION;

        lastProposalTime[msg.sender] = block.timestamp;
        userProposals[msg.sender].push(proposalId);

        activeProposals.push(proposalId);
        activeProposalIndex[proposalId] = activeProposals.length - 1;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            newProposal.startTime,
            newProposal.endTime
        );
    }

    function vote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 voterWeight = governanceToken.balanceOf(msg.sender);
        require(voterWeight > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voterWeight[msg.sender] = voterWeight;

        if (support) {
            proposal.votesFor += voterWeight;
        } else {
            proposal.votesAgainst += voterWeight;
        }

        emit VoteCast(proposalId, msg.sender, support, voterWeight);
    }

    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");

        _updateTotalSupplyCache();

        uint256 quorum = (totalSupplyCache * QUORUM_PERCENTAGE) / 100;
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;

        require(totalVotes >= quorum, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;
        _removeFromActiveProposals(proposalId);

        emit ProposalExecuted(proposalId);
    }

    function getProposalInfo(uint256 proposalId)
        external
        view
        returns (ProposalInfo memory)
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        return ProposalInfo({
            id: proposal.id,
            proposer: proposal.proposer,
            description: proposal.description,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed
        });
    }

    function getActiveProposals() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        uint256[] memory tempActive = new uint256[](activeProposals.length);

        for (uint256 i = 0; i < activeProposals.length; i++) {
            uint256 proposalId = activeProposals[i];
            if (proposalId != 0 && block.timestamp <= proposals[proposalId].endTime) {
                tempActive[activeCount] = proposalId;
                activeCount++;
            }
        }

        uint256[] memory result = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = tempActive[i];
        }

        return result;
    }

    function getUserProposals(address user)
        external
        view
        returns (uint256[] memory)
    {
        return userProposals[user];
    }

    function hasUserVoted(uint256 proposalId, address user)
        external
        view
        returns (bool)
    {
        return proposals[proposalId].hasVoted[user];
    }

    function getUserVoteWeight(uint256 proposalId, address user)
        external
        view
        returns (uint256)
    {
        return proposals[proposalId].voterWeight[user];
    }

    function getQuorumThreshold() external view returns (uint256) {
        uint256 currentSupply = (block.timestamp - lastCacheUpdate > 1 hours)
            ? governanceToken.totalSupply()
            : totalSupplyCache;
        return (currentSupply * QUORUM_PERCENTAGE) / 100;
    }

    function _updateTotalSupplyCache() private {
        if (block.timestamp - lastCacheUpdate > 1 hours) {
            totalSupplyCache = governanceToken.totalSupply();
            lastCacheUpdate = block.timestamp;
        }
    }

    function _removeFromActiveProposals(uint256 proposalId) private {
        uint256 index = activeProposalIndex[proposalId];
        uint256 lastIndex = activeProposals.length - 1;

        if (index != lastIndex) {
            uint256 lastProposalId = activeProposals[lastIndex];
            activeProposals[index] = lastProposalId;
            activeProposalIndex[lastProposalId] = index;
        }

        activeProposals.pop();
        delete activeProposalIndex[proposalId];
    }

    function cleanupExpiredProposals() external {
        uint256 i = 0;
        while (i < activeProposals.length) {
            uint256 proposalId = activeProposals[i];
            if (block.timestamp > proposals[proposalId].endTime) {
                _removeFromActiveProposals(proposalId);
            } else {
                i++;
            }
        }
    }
}
