
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    struct Member {
        address memberAddress;
        uint256 votingPower;
        uint256 joinTime;
        bool isActive;
        uint256 proposalsCreated;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => uint256) public tokenBalance;

    address[] public memberList;
    uint256 public proposalCount;
    uint256 public totalSupply;
    uint256 public quorumPercentage = 30;
    uint256 public votingDuration = 7 days;
    address public admin;
    bool public paused;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    constructor() {
        admin = msg.sender;
        totalSupply = 1000000;
        tokenBalance[msg.sender] = totalSupply;
        members[msg.sender] = Member({
            memberAddress: msg.sender,
            votingPower: totalSupply,
            joinTime: block.timestamp,
            isActive: true,
            proposalsCreated: 0
        });
        memberList.push(msg.sender);
    }




    function createProposalAndManageMembers(
        string memory title,
        string memory description,
        address newMember,
        uint256 newMemberTokens,
        bool shouldAddMember,
        uint256 customVotingDuration,
        bool updateQuorum,
        uint256 newQuorumPercentage
    ) public returns (uint256) {
        require(!paused, "Contract is paused");
        require(members[msg.sender].isActive, "Not an active member");


        proposalCount++;
        uint256 proposalId = proposalCount;

        proposals[proposalId].id = proposalId;
        proposals[proposalId].title = title;
        proposals[proposalId].description = description;
        proposals[proposalId].proposer = msg.sender;
        proposals[proposalId].startTime = block.timestamp;


        if (customVotingDuration > 0) {
            if (customVotingDuration < 1 days) {
                proposals[proposalId].endTime = block.timestamp + 1 days;
            } else {
                if (customVotingDuration > 30 days) {
                    proposals[proposalId].endTime = block.timestamp + 30 days;
                } else {
                    proposals[proposalId].endTime = block.timestamp + customVotingDuration;
                }
            }
        } else {
            proposals[proposalId].endTime = block.timestamp + votingDuration;
        }


        if (shouldAddMember) {
            if (newMember != address(0)) {
                if (!members[newMember].isActive) {
                    if (newMemberTokens > 0 && newMemberTokens <= 10000) {
                        members[newMember] = Member({
                            memberAddress: newMember,
                            votingPower: newMemberTokens,
                            joinTime: block.timestamp,
                            isActive: true,
                            proposalsCreated: 0
                        });
                        memberList.push(newMember);
                        tokenBalance[newMember] = newMemberTokens;
                        totalSupply += newMemberTokens;
                    }
                }
            }
        }


        if (updateQuorum) {
            if (newQuorumPercentage >= 10 && newQuorumPercentage <= 80) {
                if (members[msg.sender].votingPower >= totalSupply / 10) {
                    quorumPercentage = newQuorumPercentage;
                }
            }
        }

        members[msg.sender].proposalsCreated++;

        emit ProposalCreated(proposalId, msg.sender);
        return proposalId;
    }


    function calculateVotingPower(address member) public view returns (uint256) {
        return tokenBalance[member] + (members[member].proposalsCreated * 100);
    }


    function isQuorumReached(uint256 proposalId) public view returns (bool) {
        uint256 totalVotes = proposals[proposalId].forVotes + proposals[proposalId].againstVotes;
        return totalVotes >= (totalSupply * quorumPercentage) / 100;
    }


    function vote(uint256 proposalId, bool support) public {
        require(!paused, "Contract is paused");
        require(members[msg.sender].isActive, "Not an active member");
        require(block.timestamp >= proposals[proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");
        require(!proposals[proposalId].hasVoted[msg.sender], "Already voted");

        proposals[proposalId].hasVoted[msg.sender] = true;
        proposals[proposalId].voteChoice[msg.sender] = support;

        uint256 votePower = calculateVotingPower(msg.sender);

        if (support) {
            proposals[proposalId].forVotes += votePower;
        } else {
            proposals[proposalId].againstVotes += votePower;
        }

        emit VoteCast(proposalId, msg.sender, support);
    }


    function executeProposal(uint256 proposalId) public returns (uint256) {
        require(!paused, "Contract is paused");
        require(block.timestamp > proposals[proposalId].endTime, "Voting still active");
        require(!proposals[proposalId].executed, "Already executed");
        require(isQuorumReached(proposalId), "Quorum not reached");
        require(proposals[proposalId].forVotes > proposals[proposalId].againstVotes, "Proposal rejected");

        proposals[proposalId].executed = true;

        emit ProposalExecuted(proposalId);


        return block.timestamp;
    }

    function transferTokens(address to, uint256 amount) public {
        require(!paused, "Contract is paused");
        require(tokenBalance[msg.sender] >= amount, "Insufficient balance");
        require(to != address(0), "Invalid address");

        tokenBalance[msg.sender] -= amount;
        tokenBalance[to] += amount;


        members[msg.sender].votingPower = calculateVotingPower(msg.sender);
        members[to].votingPower = calculateVotingPower(to);
    }

    function pauseContract() public {
        require(msg.sender == admin, "Only admin");
        paused = !paused;
    }

    function getProposalInfo(uint256 proposalId) public view returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.endTime,
            proposal.executed
        );
    }

    function getMemberCount() public view returns (uint256) {
        return memberList.length;
    }
}
