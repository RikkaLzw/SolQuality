
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    address public owner;
    uint256 public totalSupply;
    uint256 public proposalCounter;
    uint256 public votingPeriod;
    uint256 public quorumPercentage;

    mapping(address => uint256) public balances;
    mapping(address => bool) public members;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public votes;

    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool exists;
    }

    event ProposalCreated(uint256 proposalId, address proposer, string title);
    event VoteCast(uint256 proposalId, address voter, uint256 weight, bool support);
    event ProposalExecuted(uint256 proposalId);
    event MemberAdded(address member);
    event MemberRemoved(address member);
    event TokensMinted(address to, uint256 amount);

    constructor() {
        owner = msg.sender;
        totalSupply = 0;
        proposalCounter = 0;
        votingPeriod = 604800;
        quorumPercentage = 25;
        members[msg.sender] = true;
        balances[msg.sender] = 1000000;
        totalSupply = 1000000;
    }

    function addMember(address newMember) external {

        if (msg.sender != owner) {
            revert("Only owner can add members");
        }

        members[newMember] = true;
        emit MemberAdded(newMember);
    }

    function removeMember(address memberToRemove) external {

        if (msg.sender != owner) {
            revert("Only owner can remove members");
        }

        members[memberToRemove] = false;
        emit MemberRemoved(memberToRemove);
    }

    function mintTokens(address to, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can mint tokens");
        }

        balances[to] += amount;
        totalSupply += amount;
        emit TokensMinted(to, amount);
    }

    function createProposal(string memory title, string memory description) external returns (uint256) {

        if (!members[msg.sender]) {
            revert("Only members can create proposals");
        }


        if (balances[msg.sender] < 1000) {
            revert("Insufficient tokens to create proposal");
        }

        proposalCounter++;
        uint256 proposalId = proposalCounter;

        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            proposer: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + 604800,
            forVotes: 0,
            againstVotes: 0,
            executed: false,
            exists: true
        });

        emit ProposalCreated(proposalId, msg.sender, title);
        return proposalId;
    }

    function voteOnProposal(uint256 proposalId, bool support) external {

        if (!members[msg.sender]) {
            revert("Only members can vote");
        }


        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }


        if (block.timestamp < proposals[proposalId].startTime || block.timestamp > proposals[proposalId].endTime) {
            revert("Voting period has ended or not started");
        }


        if (hasVoted[proposalId][msg.sender]) {
            revert("Already voted on this proposal");
        }

        uint256 voterWeight = balances[msg.sender];


        if (voterWeight == 0) {
            revert("No voting power");
        }

        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = voterWeight;

        if (support) {
            proposals[proposalId].forVotes += voterWeight;
        } else {
            proposals[proposalId].againstVotes += voterWeight;
        }

        emit VoteCast(proposalId, msg.sender, voterWeight, support);
    }

    function executeProposal(uint256 proposalId) external {

        if (!members[msg.sender]) {
            revert("Only members can execute proposals");
        }


        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }


        if (proposals[proposalId].executed) {
            revert("Proposal already executed");
        }


        if (block.timestamp <= proposals[proposalId].endTime) {
            revert("Voting period not ended");
        }

        uint256 totalVotes = proposals[proposalId].forVotes + proposals[proposalId].againstVotes;
        uint256 requiredQuorum = (totalSupply * 25) / 100;


        if (totalVotes < requiredQuorum) {
            revert("Quorum not reached");
        }


        if (proposals[proposalId].forVotes <= proposals[proposalId].againstVotes) {
            revert("Proposal rejected");
        }

        proposals[proposalId].executed = true;
        emit ProposalExecuted(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        string memory title,
        string memory description,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool exists
    ) {
        Proposal memory proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.exists
        );
    }

    function getVotingPower(address voter) external view returns (uint256) {
        return balances[voter];
    }

    function hasUserVoted(uint256 proposalId, address voter) external view returns (bool) {
        return hasVoted[proposalId][voter];
    }

    function getUserVote(uint256 proposalId, address voter) external view returns (uint256) {
        return votes[proposalId][voter];
    }

    function isMember(address user) external view returns (bool) {
        return members[user];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCounter;
    }

    function changeVotingPeriod(uint256 newPeriod) external {

        if (msg.sender != owner) {
            revert("Only owner can change voting period");
        }

        votingPeriod = newPeriod;
    }

    function changeQuorumPercentage(uint256 newQuorum) external {

        if (msg.sender != owner) {
            revert("Only owner can change quorum");
        }


        if (newQuorum > 100) {
            revert("Quorum cannot exceed 100%");
        }

        quorumPercentage = newQuorum;
    }

    function transferTokens(address to, uint256 amount) external {

        if (balances[msg.sender] < amount) {
            revert("Insufficient balance");
        }


        if (to == address(0)) {
            revert("Cannot transfer to zero address");
        }

        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    function delegateVote(uint256 proposalId, address delegate, bool support) external {

        if (!members[msg.sender]) {
            revert("Only members can delegate votes");
        }


        if (!members[delegate]) {
            revert("Delegate must be a member");
        }


        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }


        if (block.timestamp < proposals[proposalId].startTime || block.timestamp > proposals[proposalId].endTime) {
            revert("Voting period has ended or not started");
        }


        if (hasVoted[proposalId][msg.sender]) {
            revert("Already voted on this proposal");
        }

        uint256 voterWeight = balances[msg.sender];


        if (voterWeight == 0) {
            revert("No voting power");
        }

        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = voterWeight;

        if (support) {
            proposals[proposalId].forVotes += voterWeight;
        } else {
            proposals[proposalId].againstVotes += voterWeight;
        }

        emit VoteCast(proposalId, delegate, voterWeight, support);
    }
}
