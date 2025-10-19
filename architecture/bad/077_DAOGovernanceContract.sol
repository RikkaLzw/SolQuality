
pragma solidity ^0.8.0;

contract DAOGovernanceContract {


    address owner;
    mapping(address => uint256) tokenBalances;
    mapping(uint256 => Proposal) proposals;
    mapping(uint256 => mapping(address => bool)) hasVoted;
    mapping(uint256 => mapping(address => uint256)) votes;
    uint256 proposalCounter;
    uint256 totalSupply;
    mapping(address => bool) members;
    uint256 memberCount;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool exists;
    }

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint256 votes, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event TokensMinted(address indexed to, uint256 amount);
    event MemberAdded(address indexed member);

    constructor() {
        owner = msg.sender;
        totalSupply = 1000000 * 10**18;
        tokenBalances[msg.sender] = totalSupply;
        members[msg.sender] = true;
        memberCount = 1;
    }

    function createProposal(string memory description) external {

        if (tokenBalances[msg.sender] < 1000 * 10**18) {
            revert("Insufficient tokens to create proposal");
        }
        if (!members[msg.sender]) {
            revert("Only members can create proposals");
        }

        proposalCounter++;
        uint256 proposalId = proposalCounter;


        uint256 votingPeriod = 7 days;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            executed: false,
            exists: true
        });

        emit ProposalCreated(proposalId, msg.sender, description);
    }

    function vote(uint256 proposalId, bool support, uint256 voteAmount) external {

        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }
        if (block.timestamp < proposals[proposalId].startTime) {
            revert("Voting has not started");
        }
        if (block.timestamp > proposals[proposalId].endTime) {
            revert("Voting has ended");
        }
        if (hasVoted[proposalId][msg.sender]) {
            revert("Already voted");
        }
        if (voteAmount > tokenBalances[msg.sender]) {
            revert("Insufficient token balance");
        }
        if (!members[msg.sender]) {
            revert("Only members can vote");
        }

        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = voteAmount;

        if (support) {
            proposals[proposalId].forVotes += voteAmount;
        } else {
            proposals[proposalId].againstVotes += voteAmount;
        }

        emit VoteCast(proposalId, msg.sender, voteAmount, support);
    }

    function executeProposal(uint256 proposalId) external {

        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }
        if (block.timestamp <= proposals[proposalId].endTime) {
            revert("Voting period not ended");
        }
        if (proposals[proposalId].executed) {
            revert("Proposal already executed");
        }


        uint256 quorumRequired = (totalSupply * 10) / 100;
        uint256 totalVotes = proposals[proposalId].forVotes + proposals[proposalId].againstVotes;

        if (totalVotes < quorumRequired) {
            revert("Quorum not reached");
        }

        if (proposals[proposalId].forVotes <= proposals[proposalId].againstVotes) {
            revert("Proposal rejected");
        }

        proposals[proposalId].executed = true;
        emit ProposalExecuted(proposalId);
    }

    function mintTokens(address to, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can mint tokens");
        }

        tokenBalances[to] += amount;
        totalSupply += amount;
        emit TokensMinted(to, amount);
    }

    function addMember(address newMember) external {

        if (msg.sender != owner) {
            revert("Only owner can add members");
        }
        if (members[newMember]) {
            revert("Already a member");
        }

        members[newMember] = true;
        memberCount++;
        emit MemberAdded(newMember);
    }

    function removeMember(address member) external {

        if (msg.sender != owner) {
            revert("Only owner can remove members");
        }
        if (!members[member]) {
            revert("Not a member");
        }
        if (member == owner) {
            revert("Cannot remove owner");
        }

        members[member] = false;
        memberCount--;
    }

    function transfer(address to, uint256 amount) external {
        if (tokenBalances[msg.sender] < amount) {
            revert("Insufficient balance");
        }
        if (to == address(0)) {
            revert("Cannot transfer to zero address");
        }

        tokenBalances[msg.sender] -= amount;
        tokenBalances[to] += amount;
    }

    function delegateVote(uint256 proposalId, address delegate, uint256 voteAmount) external {

        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }
        if (block.timestamp < proposals[proposalId].startTime) {
            revert("Voting has not started");
        }
        if (block.timestamp > proposals[proposalId].endTime) {
            revert("Voting has ended");
        }
        if (hasVoted[proposalId][msg.sender]) {
            revert("Already voted");
        }
        if (voteAmount > tokenBalances[msg.sender]) {
            revert("Insufficient token balance");
        }
        if (!members[msg.sender]) {
            revert("Only members can delegate votes");
        }
        if (!members[delegate]) {
            revert("Delegate must be a member");
        }

        hasVoted[proposalId][msg.sender] = true;
        tokenBalances[delegate] += voteAmount;
        tokenBalances[msg.sender] -= voteAmount;
    }

    function emergencyPause(uint256 proposalId) external {

        if (msg.sender != owner) {
            revert("Only owner can emergency pause");
        }
        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }


        proposals[proposalId].endTime = block.timestamp + 1 days;
    }

    function updateQuorum(uint256 newQuorumPercentage) external {

        if (msg.sender != owner) {
            revert("Only owner can update quorum");
        }

        if (newQuorumPercentage > 50) {
            revert("Quorum cannot exceed 50%");
        }



    }


    function getProposal(uint256 proposalId) public view returns (Proposal memory) {

        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }
        return proposals[proposalId];
    }

    function getTokenBalance(address account) public view returns (uint256) {
        return tokenBalances[account];
    }

    function isMember(address account) public view returns (bool) {
        return members[account];
    }

    function getTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function getProposalCount() public view returns (uint256) {
        return proposalCounter;
    }

    function getMemberCount() public view returns (uint256) {
        return memberCount;
    }

    function hasVotedOnProposal(uint256 proposalId, address voter) public view returns (bool) {
        return hasVoted[proposalId][voter];
    }

    function getVoteAmount(uint256 proposalId, address voter) public view returns (uint256) {
        return votes[proposalId][voter];
    }

    function calculateQuorum() public view returns (uint256) {

        return (totalSupply * 10) / 100;
    }

    function isProposalActive(uint256 proposalId) public view returns (bool) {

        if (!proposals[proposalId].exists) {
            return false;
        }
        return block.timestamp >= proposals[proposalId].startTime &&
               block.timestamp <= proposals[proposalId].endTime;
    }

    function canExecuteProposal(uint256 proposalId) public view returns (bool) {

        if (!proposals[proposalId].exists) {
            return false;
        }
        if (block.timestamp <= proposals[proposalId].endTime) {
            return false;
        }
        if (proposals[proposalId].executed) {
            return false;
        }


        uint256 quorumRequired = (totalSupply * 10) / 100;
        uint256 totalVotes = proposals[proposalId].forVotes + proposals[proposalId].againstVotes;

        return totalVotes >= quorumRequired &&
               proposals[proposalId].forVotes > proposals[proposalId].againstVotes;
    }
}
