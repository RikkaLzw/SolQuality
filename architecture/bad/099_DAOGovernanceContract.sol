
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    address internal owner;
    mapping(address => uint256) internal balances;
    mapping(address => bool) internal members;
    mapping(uint256 => Proposal) internal proposals;
    mapping(uint256 => mapping(address => bool)) internal hasVoted;
    mapping(uint256 => mapping(address => bool)) internal votes;
    uint256 internal proposalCount;
    uint256 internal totalSupply;
    address[] internal memberList;

    struct Proposal {
        uint256 id;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        bool exists;
    }

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);

    constructor() {
        owner = msg.sender;
        members[msg.sender] = true;
        memberList.push(msg.sender);
        balances[msg.sender] = 1000000;
        totalSupply = 1000000;
    }

    function createProposal(string memory description) public {

        bool isMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        require(isMember, "Not a member");


        require(balances[msg.sender] >= 100, "Insufficient balance");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: description,
            proposer: msg.sender,
            forVotes: 0,
            againstVotes: 0,
            deadline: block.timestamp + 604800,
            executed: false,
            exists: true
        });

        emit ProposalCreated(proposalCount, msg.sender, description);
    }

    function vote(uint256 proposalId, bool support) public {

        bool isMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        require(isMember, "Not a member");

        require(proposals[proposalId].exists, "Proposal does not exist");
        require(block.timestamp <= proposals[proposalId].deadline, "Voting period ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = support;

        uint256 voterBalance = balances[msg.sender];
        if (support) {
            proposals[proposalId].forVotes += voterBalance;
        } else {
            proposals[proposalId].againstVotes += voterBalance;
        }

        emit VoteCast(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) public {

        bool isMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        require(isMember, "Not a member");

        require(proposals[proposalId].exists, "Proposal does not exist");
        require(block.timestamp > proposals[proposalId].deadline, "Voting still active");
        require(!proposals[proposalId].executed, "Already executed");


        uint256 totalVotes = proposals[proposalId].forVotes + proposals[proposalId].againstVotes;
        require(totalVotes >= totalSupply / 2, "Quorum not reached");
        require(proposals[proposalId].forVotes > proposals[proposalId].againstVotes, "Proposal rejected");

        proposals[proposalId].executed = true;
        emit ProposalExecuted(proposalId);
    }

    function addMember(address newMember) public {

        require(msg.sender == owner, "Only owner");

        require(!members[newMember], "Already a member");
        members[newMember] = true;
        memberList.push(newMember);
        balances[newMember] = 1000;
        totalSupply += 1000;

        emit MemberAdded(newMember);
    }

    function removeMember(address member) public {

        require(msg.sender == owner, "Only owner");

        require(members[member], "Not a member");
        require(member != owner, "Cannot remove owner");

        members[member] = false;
        totalSupply -= balances[member];
        balances[member] = 0;


        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == member) {
                memberList[i] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }

        emit MemberRemoved(member);
    }

    function transferTokens(address to, uint256 amount) public {

        bool isMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        require(isMember, "Not a member");


        bool isRecipientMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == to) {
                isRecipientMember = true;
                break;
            }
        }
        require(isRecipientMember, "Recipient not a member");

        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be positive");

        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    function delegateVote(uint256 proposalId, address delegate, bool support) public {

        bool isMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == msg.sender) {
                isMember = true;
                break;
            }
        }
        require(isMember, "Not a member");


        bool isDelegateMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == delegate) {
                isDelegateMember = true;
                break;
            }
        }
        require(isDelegateMember, "Delegate not a member");

        require(proposals[proposalId].exists, "Proposal does not exist");
        require(block.timestamp <= proposals[proposalId].deadline, "Voting period ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(delegate != msg.sender, "Cannot delegate to self");

        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = support;

        uint256 voterBalance = balances[msg.sender];
        if (support) {
            proposals[proposalId].forVotes += voterBalance;
        } else {
            proposals[proposalId].againstVotes += voterBalance;
        }

        emit VoteCast(proposalId, msg.sender, support);
    }

    function changeOwner(address newOwner) public {

        require(msg.sender == owner, "Only owner");


        bool isNewOwnerMember = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == newOwner) {
                isNewOwnerMember = true;
                break;
            }
        }
        require(isNewOwnerMember, "New owner must be a member");

        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    function getProposal(uint256 proposalId) public view returns (
        uint256 id,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 deadline,
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
            proposal.deadline,
            proposal.executed,
            proposal.exists
        );
    }

    function getBalance(address account) public view returns (uint256) {
        return balances[account];
    }

    function isMember(address account) public view returns (bool) {
        return members[account];
    }

    function getMemberCount() public view returns (uint256) {
        return memberList.length;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function getProposalCount() public view returns (uint256) {
        return proposalCount;
    }

    function hasVotedOnProposal(uint256 proposalId, address voter) public view returns (bool) {
        return hasVoted[proposalId][voter];
    }

    function getVote(uint256 proposalId, address voter) public view returns (bool) {
        require(hasVoted[proposalId][voter], "Has not voted");
        return votes[proposalId][voter];
    }
}
