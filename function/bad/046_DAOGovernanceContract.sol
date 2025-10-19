
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
        uint256 totalVotesCast;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => uint256) public tokenBalances;

    address[] public membersList;
    uint256 public proposalCount;
    uint256 public totalSupply;
    uint256 public quorumPercentage;
    address public admin;
    bool public paused;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool success);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not an active member");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
        quorumPercentage = 30;
        totalSupply = 1000000 * 10**18;
        tokenBalances[admin] = totalSupply;
    }




    function createProposalAndManageMembers(
        string memory title,
        string memory description,
        address newMember,
        uint256 newMemberVotingPower,
        bool shouldAddMember,
        uint256 proposalDuration,
        bool updateQuorum,
        uint256 newQuorumPercentage
    ) public onlyMember notPaused {

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + proposalDuration;


        if (shouldAddMember && newMember != address(0)) {
            if (!members[newMember].isActive) {
                members[newMember] = Member({
                    memberAddress: newMember,
                    votingPower: newMemberVotingPower,
                    joinTime: block.timestamp,
                    isActive: true,
                    proposalsCreated: 0,
                    totalVotesCast: 0
                });
                membersList.push(newMember);
            }
        }


        if (updateQuorum && newQuorumPercentage > 0 && newQuorumPercentage <= 100) {
            quorumPercentage = newQuorumPercentage;
        }


        members[msg.sender].proposalsCreated++;

        emit ProposalCreated(proposalCount, msg.sender, title);
    }



    function complexVotingAndCalculation(uint256 proposalId, bool support) public onlyMember notPaused {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");


        if (members[msg.sender].isActive) {
            if (members[msg.sender].votingPower > 0) {
                if (tokenBalances[msg.sender] >= 1000 * 10**18) {

                    if (support) {
                        if (members[msg.sender].totalVotesCast < 10) {

                            proposal.forVotes += members[msg.sender].votingPower * 2;
                            if (proposal.forVotes > proposal.againstVotes * 3) {

                                if (block.timestamp - proposal.startTime < 86400) {

                                    proposal.forVotes += members[msg.sender].votingPower / 2;
                                }
                            }
                        } else {
                            proposal.forVotes += members[msg.sender].votingPower;
                        }
                    } else {
                        if (members[msg.sender].totalVotesCast >= 50) {

                            proposal.againstVotes += members[msg.sender].votingPower * 2;
                            if (proposal.againstVotes > proposal.forVotes) {
                                if (block.timestamp - proposal.startTime > 172800) {

                                    proposal.againstVotes += members[msg.sender].votingPower / 2;
                                }
                            }
                        } else {
                            proposal.againstVotes += members[msg.sender].votingPower;
                        }
                    }
                } else {

                    if (support) {
                        proposal.forVotes += members[msg.sender].votingPower;
                        if (members[msg.sender].proposalsCreated > 5) {

                            proposal.forVotes += members[msg.sender].votingPower / 4;
                        }
                    } else {
                        proposal.againstVotes += members[msg.sender].votingPower;
                    }
                }
            }
        }

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;
        members[msg.sender].totalVotesCast++;

        emit VoteCast(proposalId, msg.sender, support, members[msg.sender].votingPower);
    }


    function calculateQuorumAndExecute(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (getTotalVotingPower() * quorumPercentage) / 100;

        if (totalVotes >= requiredQuorum && proposal.forVotes > proposal.againstVotes) {
            proposal.executed = true;
            emit ProposalExecuted(proposalId, true);
        } else {
            proposal.executed = true;
            emit ProposalExecuted(proposalId, false);
        }
    }

    function getTotalVotingPower() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < membersList.length; i++) {
            if (members[membersList[i]].isActive) {
                total += members[membersList[i]].votingPower;
            }
        }
        return total;
    }

    function getProposalDetails(uint256 proposalId) public view returns (
        uint256 id,
        string memory title,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function hasVoted(uint256 proposalId, address voter) public view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) public view returns (bool) {
        return proposals[proposalId].voteChoice[voter];
    }

    function addMember(address newMember, uint256 votingPower) public onlyAdmin {
        require(!members[newMember].isActive, "Already a member");
        members[newMember] = Member({
            memberAddress: newMember,
            votingPower: votingPower,
            joinTime: block.timestamp,
            isActive: true,
            proposalsCreated: 0,
            totalVotesCast: 0
        });
        membersList.push(newMember);
    }

    function removeMember(address member) public onlyAdmin {
        members[member].isActive = false;
    }

    function transferTokens(address to, uint256 amount) public {
        require(tokenBalances[msg.sender] >= amount, "Insufficient balance");
        tokenBalances[msg.sender] -= amount;
        tokenBalances[to] += amount;
    }

    function setPaused(bool _paused) public onlyAdmin {
        paused = _paused;
    }

    function updateQuorum(uint256 newPercentage) public onlyAdmin {
        require(newPercentage > 0 && newPercentage <= 100, "Invalid percentage");
        quorumPercentage = newPercentage;
    }

    function getMemberCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < membersList.length; i++) {
            if (members[membersList[i]].isActive) {
                count++;
            }
        }
        return count;
    }
}
