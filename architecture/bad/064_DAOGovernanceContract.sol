
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
        string description;
        address proposer;
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


        proposals[proposalCounter] = Proposal({
            id: proposalCounter,
            description: description,
            proposer: msg.sender,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + 604800,
            executed: false,
            exists: true
        });

        emit ProposalCreated(proposalCounter, msg.sender, description);
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


        uint256 quorum = totalSupply * 10 / 100;
        uint256 totalVotes = proposals[proposalId].forVotes + proposals[proposalId].againstVotes;

        if (totalVotes < quorum) {
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

    function transferTokens(address to, uint256 amount) external {
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
            revert("Only members can delegate");
        }
        if (!members[delegate]) {
            revert("Delegate must be a member");
        }

        hasVoted[proposalId][msg.sender] = true;
        tokenBalances[delegate] += voteAmount;
        tokenBalances[msg.sender] -= voteAmount;
    }

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool exists
    ) {
        Proposal memory proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.exists
        );
    }

    function getTokenBalance(address account) external view returns (uint256) {
        return tokenBalances[account];
    }

    function isMember(address account) external view returns (bool) {
        return members[account];
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    function getMemberCount() external view returns (uint256) {
        return memberCount;
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCounter;
    }

    function hasVotedOnProposal(uint256 proposalId, address voter) external view returns (bool) {
        return hasVoted[proposalId][voter];
    }

    function getVoteAmount(uint256 proposalId, address voter) external view returns (uint256) {
        return votes[proposalId][voter];
    }

    function changeOwner(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can change owner");
        }
        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = newOwner;
    }

    function emergencyPause() external {

        if (msg.sender != owner) {
            revert("Only owner can pause");
        }

    }

    function bulkAddMembers(address[] memory newMembers) external {

        if (msg.sender != owner) {
            revert("Only owner can bulk add members");
        }


        if (newMembers.length > 50) {
            revert("Too many members in batch");
        }

        for (uint256 i = 0; i < newMembers.length; i++) {
            if (!members[newMembers[i]]) {
                members[newMembers[i]] = true;
                memberCount++;
                emit MemberAdded(newMembers[i]);
            }
        }
    }

    function calculateVotingPower(address voter) external view returns (uint256) {

        uint256 basePower = tokenBalances[voter];
        if (members[voter]) {
            return basePower * 110 / 100;
        }
        return basePower;
    }
}
