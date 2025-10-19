
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAOGovernance is Ownable, ReentrancyGuard {
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterWeights;
    }

    struct ProposalView {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }

    IERC20 public immutable governanceToken;


    uint256 public proposalCount;
    uint256 public votingDuration = 7 days;
    uint256 public minTokensToPropose = 1000 * 10**18;
    uint256 public quorumPercentage = 10;

    mapping(uint256 => Proposal) private proposals;
    mapping(address => uint256) public memberTokenBalance;


    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event TokensDeposited(address indexed member, uint256 amount);
    event TokensWithdrawn(address indexed member, uint256 amount);

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }

    modifier onlyMembers() {
        require(memberTokenBalance[msg.sender] > 0, "Not a DAO member");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    function depositTokens(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(governanceToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        memberTokenBalance[msg.sender] += _amount;
        emit TokensDeposited(msg.sender, _amount);
    }

    function withdrawTokens(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(memberTokenBalance[msg.sender] >= _amount, "Insufficient balance");

        memberTokenBalance[msg.sender] -= _amount;
        require(governanceToken.transfer(msg.sender, _amount), "Transfer failed");
        emit TokensWithdrawn(msg.sender, _amount);
    }

    function createProposal(
        string calldata _title,
        string calldata _description
    ) external onlyMembers returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(memberTokenBalance[msg.sender] >= minTokensToPropose, "Insufficient tokens to propose");


        uint256 newProposalId = ++proposalCount;

        Proposal storage newProposal = proposals[newProposalId];
        newProposal.id = newProposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingDuration;
        newProposal.executed = false;

        emit ProposalCreated(newProposalId, msg.sender, _title);
        return newProposalId;
    }

    function vote(uint256 _proposalId, bool _support) external onlyMembers validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Proposal already executed");


        uint256 voterWeight = memberTokenBalance[msg.sender];
        require(voterWeight > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voterWeights[msg.sender] = voterWeight;

        if (_support) {
            proposal.votesFor += voterWeight;
        } else {
            proposal.votesAgainst += voterWeight;
        }

        emit VoteCast(_proposalId, msg.sender, _support, voterWeight);
    }

    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");


        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorumRequired = (totalSupply * quorumPercentage) / 100;
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;

        require(totalVotes >= quorumRequired, "Quorum not reached");

        proposal.executed = true;
        bool success = proposal.votesFor > proposal.votesAgainst;

        emit ProposalExecuted(_proposalId, success);
    }

    function getProposal(uint256 _proposalId) external view validProposal(_proposalId) returns (ProposalView memory) {
        Proposal storage proposal = proposals[_proposalId];

        return ProposalView({
            id: proposal.id,
            proposer: proposal.proposer,
            title: proposal.title,
            description: proposal.description,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed
        });
    }

    function hasVoted(uint256 _proposalId, address _voter) external view validProposal(_proposalId) returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getVoterWeight(uint256 _proposalId, address _voter) external view validProposal(_proposalId) returns (uint256) {
        return proposals[_proposalId].voterWeights[_voter];
    }

    function isProposalActive(uint256 _proposalId) external view validProposal(_proposalId) returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        return block.timestamp >= proposal.startTime &&
               block.timestamp <= proposal.endTime &&
               !proposal.executed;
    }

    function getQuorumRequired() external view returns (uint256) {
        return (governanceToken.totalSupply() * quorumPercentage) / 100;
    }


    function setVotingDuration(uint256 _newDuration) external onlyOwner {
        require(_newDuration >= 1 days && _newDuration <= 30 days, "Invalid duration");
        votingDuration = _newDuration;
    }

    function setMinTokensToPropose(uint256 _newAmount) external onlyOwner {
        require(_newAmount > 0, "Amount must be greater than 0");
        minTokensToPropose = _newAmount;
    }

    function setQuorumPercentage(uint256 _newPercentage) external onlyOwner {
        require(_newPercentage > 0 && _newPercentage <= 100, "Invalid percentage");
        quorumPercentage = _newPercentage;
    }
}
