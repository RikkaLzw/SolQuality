
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voteWeight;
    }

    struct Member {
        address memberAddress;
        uint256 votingPower;
        uint256 joinTime;
        bool isActive;
        uint256 reputation;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => uint256) public memberTokens;

    address[] public memberList;
    uint256 public proposalCount;
    uint256 public totalVotingPower;
    uint256 public quorumPercentage = 30;
    uint256 public votingPeriod = 7 days;
    address public admin;
    bool public paused;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive, "Only active member");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor() {
        admin = msg.sender;
        members[msg.sender] = Member({
            memberAddress: msg.sender,
            votingPower: 100,
            joinTime: block.timestamp,
            isActive: true,
            reputation: 100
        });
        memberList.push(msg.sender);
        totalVotingPower = 100;
    }




    function createProposalAndManageMembers(
        string memory title,
        string memory description,
        address newMember,
        uint256 newMemberVotingPower,
        bool addMember,
        uint256 reputationBonus,
        bool updateReputation
    ) public onlyMember notPaused {

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalCount, msg.sender);


        if (addMember && newMember != address(0)) {
            if (!members[newMember].isActive) {
                members[newMember] = Member({
                    memberAddress: newMember,
                    votingPower: newMemberVotingPower,
                    joinTime: block.timestamp,
                    isActive: true,
                    reputation: 50
                });
                memberList.push(newMember);
                totalVotingPower += newMemberVotingPower;
                emit MemberAdded(newMember);
            }
        }


        if (updateReputation) {
            members[msg.sender].reputation += reputationBonus;
        }
    }



    function voteOnProposalWithComplexLogic(uint256 proposalId, bool support) public onlyMember notPaused {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");


        if (members[msg.sender].isActive) {
            if (members[msg.sender].votingPower > 0) {
                if (block.timestamp >= proposal.startTime) {
                    if (!proposal.executed) {
                        uint256 voteWeight = members[msg.sender].votingPower;


                        if (members[msg.sender].reputation > 80) {
                            if (members[msg.sender].reputation > 90) {
                                if (members[msg.sender].reputation > 95) {
                                    voteWeight = voteWeight * 150 / 100;
                                } else {
                                    voteWeight = voteWeight * 130 / 100;
                                }
                            } else {
                                voteWeight = voteWeight * 120 / 100;
                            }
                        } else {
                            if (members[msg.sender].reputation < 30) {
                                if (members[msg.sender].reputation < 20) {
                                    voteWeight = voteWeight * 50 / 100;
                                } else {
                                    voteWeight = voteWeight * 70 / 100;
                                }
                            }
                        }

                        proposal.hasVoted[msg.sender] = true;
                        proposal.voteWeight[msg.sender] = voteWeight;

                        if (support) {
                            proposal.votesFor += voteWeight;
                        } else {
                            proposal.votesAgainst += voteWeight;
                        }

                        emit VoteCast(proposalId, msg.sender, support);


                        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
                        if (totalVotes * 100 >= totalVotingPower * quorumPercentage) {
                            if (proposal.votesFor > proposal.votesAgainst) {
                                if (block.timestamp <= proposal.endTime) {
                                    proposal.executed = true;
                                    emit ProposalExecuted(proposalId);
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    function calculateVotingWeight(address voter, uint256 baseWeight) public view returns (uint256) {
        if (members[voter].reputation > 90) {
            return baseWeight * 140 / 100;
        } else if (members[voter].reputation > 70) {
            return baseWeight * 120 / 100;
        } else if (members[voter].reputation < 30) {
            return baseWeight * 80 / 100;
        }
        return baseWeight;
    }


    function executeProposal(uint256 proposalId) public onlyMember returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(!proposal.executed, "Already executed");
        require(block.timestamp > proposal.endTime, "Voting still active");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes * 100 >= totalVotingPower * quorumPercentage, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);


        return true;
    }

    function addMember(address newMember, uint256 votingPower) public onlyAdmin {
        require(newMember != address(0), "Invalid address");
        require(!members[newMember].isActive, "Already a member");

        members[newMember] = Member({
            memberAddress: newMember,
            votingPower: votingPower,
            joinTime: block.timestamp,
            isActive: true,
            reputation: 50
        });

        memberList.push(newMember);
        totalVotingPower += votingPower;
        emit MemberAdded(newMember);
    }

    function removeMember(address member) public onlyAdmin {
        require(members[member].isActive, "Not an active member");
        require(member != admin, "Cannot remove admin");

        totalVotingPower -= members[member].votingPower;
        members[member].isActive = false;
    }

    function updateQuorum(uint256 newQuorum) public onlyAdmin {
        require(newQuorum > 0 && newQuorum <= 100, "Invalid quorum");
        quorumPercentage = newQuorum;
    }

    function pauseContract() public onlyAdmin {
        paused = true;
    }

    function unpauseContract() public onlyAdmin {
        paused = false;
    }

    function getProposalInfo(uint256 proposalId) public view returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.endTime,
            proposal.executed
        );
    }

    function getMemberCount() public view returns (uint256) {
        return memberList.length;
    }

    function hasVoted(uint256 proposalId, address voter) public view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
}
