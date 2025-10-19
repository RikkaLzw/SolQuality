
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

    function createProposal(string memory description) public {

        if (tokenBalances[msg.sender] < 1000 * 10**18) {
            revert("Insufficient tokens to create proposal");
        }
        if (!members[msg.sender]) {
            revert("Only members can create proposals");
        }

        proposalCounter++;
        proposals[proposalCounter] = Proposal({
            id: proposalCounter,
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + 604800,
            executed: false,
            exists: true
        });

        emit ProposalCreated(proposalCounter, msg.sender, description);
    }

    function vote(uint256 proposalId, bool support) public {

        if (tokenBalances[msg.sender] == 0) {
            revert("No voting power");
        }
        if (!members[msg.sender]) {
            revert("Only members can vote");
        }
        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }
        if (block.timestamp < proposals[proposalId].startTime) {
            revert("Voting not started");
        }
        if (block.timestamp > proposals[proposalId].endTime) {
            revert("Voting period ended");
        }
        if (hasVoted[proposalId][msg.sender]) {
            revert("Already voted");
        }

        uint256 votingPower = tokenBalances[msg.sender];
        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = votingPower;

        if (support) {
            proposals[proposalId].forVotes += votingPower;
        } else {
            proposals[proposalId].againstVotes += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, votingPower, support);
    }

    function executeProposal(uint256 proposalId) public {

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

    function mintTokens(address to, uint256 amount) public {

        if (msg.sender != owner) {
            revert("Only owner can mint tokens");
        }

        tokenBalances[to] += amount;
        totalSupply += amount;
        emit TokensMinted(to, amount);
    }

    function addMember(address newMember) public {

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

    function transfer(address to, uint256 amount) public {

        if (tokenBalances[msg.sender] < amount) {
            revert("Insufficient balance");
        }
        if (to == address(0)) {
            revert("Cannot transfer to zero address");
        }

        tokenBalances[msg.sender] -= amount;
        tokenBalances[to] += amount;
    }

    function delegateVote(uint256 proposalId, address delegate, bool support) public {

        if (tokenBalances[msg.sender] == 0) {
            revert("No voting power");
        }
        if (!members[msg.sender]) {
            revert("Only members can delegate");
        }
        if (!members[delegate]) {
            revert("Delegate must be a member");
        }
        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }
        if (block.timestamp < proposals[proposalId].startTime) {
            revert("Voting not started");
        }
        if (block.timestamp > proposals[proposalId].endTime) {
            revert("Voting period ended");
        }
        if (hasVoted[proposalId][msg.sender]) {
            revert("Already voted");
        }

        uint256 votingPower = tokenBalances[msg.sender];
        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = votingPower;

        if (support) {
            proposals[proposalId].forVotes += votingPower;
        } else {
            proposals[proposalId].againstVotes += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, votingPower, support);
    }

    function emergencyPause(uint256 proposalId) public {

        if (msg.sender != owner) {
            revert("Only owner can pause");
        }
        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }


        proposals[proposalId].endTime = block.timestamp + 86400;
    }

    function getProposal(uint256 proposalId) public view returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {

        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }

        Proposal memory proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function getBalance(address account) public view returns (uint256) {
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

    function getVoteWeight(uint256 proposalId, address voter) public view returns (uint256) {
        return votes[proposalId][voter];
    }

    function changeOwner(address newOwner) public {

        if (msg.sender != owner) {
            revert("Only owner can change owner");
        }
        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = newOwner;
    }

    function burnTokens(uint256 amount) public {

        if (tokenBalances[msg.sender] < amount) {
            revert("Insufficient balance");
        }

        tokenBalances[msg.sender] -= amount;
        totalSupply -= amount;
    }

    function extendVotingPeriod(uint256 proposalId) public {

        if (msg.sender != owner) {
            revert("Only owner can extend voting");
        }
        if (!proposals[proposalId].exists) {
            revert("Proposal does not exist");
        }
        if (proposals[proposalId].executed) {
            revert("Cannot extend executed proposal");
        }


        proposals[proposalId].endTime += 259200;
    }
}
