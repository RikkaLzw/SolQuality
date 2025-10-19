
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    struct Proposal {
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
    }

    struct Voter {
        uint256 weight;
        bool isRegistered;
        uint256 totalVotes;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    uint256 public proposalCount;
    address public admin;
    uint256 public minVotingPeriod = 3 days;
    uint256 public quorum = 50;

    event ProposalCreated(uint256 proposalId, string title, address proposer);
    event VoteCast(uint256 proposalId, address voter, bool support, uint256 weight);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Not registered voter");
        _;
    }

    constructor() {
        admin = msg.sender;
    }




    function createProposalAndValidateAndStore(
        string memory _title,
        string memory _description,
        uint256 _votingPeriod,
        address _proposer,
        uint256 _minWeight,
        bool _requireAdminApproval
    ) public onlyRegisteredVoter {

        if (bytes(_title).length > 0) {
            if (bytes(_description).length > 0) {
                if (_votingPeriod >= minVotingPeriod) {
                    if (voters[_proposer].weight >= _minWeight) {
                        if (_requireAdminApproval) {
                            if (msg.sender == admin || voters[msg.sender].weight >= 100) {

                                proposalCount++;
                                Proposal storage newProposal = proposals[proposalCount];
                                newProposal.title = _title;
                                newProposal.description = _description;
                                newProposal.deadline = block.timestamp + _votingPeriod;
                                newProposal.proposer = _proposer;
                                newProposal.executed = false;


                                voters[_proposer].totalVotes++;


                                emit ProposalCreated(proposalCount, _title, _proposer);
                            } else {
                                revert("Admin approval required");
                            }
                        } else {

                            proposalCount++;
                            Proposal storage newProposal = proposals[proposalCount];
                            newProposal.title = _title;
                            newProposal.description = _description;
                            newProposal.deadline = block.timestamp + _votingPeriod;
                            newProposal.proposer = _proposer;
                            newProposal.executed = false;


                            voters[_proposer].totalVotes++;


                            emit ProposalCreated(proposalCount, _title, _proposer);
                        }
                    } else {
                        revert("Insufficient weight");
                    }
                } else {
                    revert("Voting period too short");
                }
            } else {
                revert("Description cannot be empty");
            }
        } else {
            revert("Title cannot be empty");
        }
    }



    function voteOnProposalWithComplexLogic(uint256 _proposalId, bool _support) public onlyRegisteredVoter {
        Proposal storage proposal = proposals[_proposalId];


        if (_proposalId > 0 && _proposalId <= proposalCount) {
            if (block.timestamp <= proposal.deadline) {
                if (!proposal.executed) {
                    if (!proposal.hasVoted[msg.sender]) {
                        if (voters[msg.sender].weight > 0) {

                            proposal.hasVoted[msg.sender] = true;

                            if (_support) {
                                proposal.votesFor += voters[msg.sender].weight;
                            } else {
                                proposal.votesAgainst += voters[msg.sender].weight;
                            }

                            emit VoteCast(_proposalId, msg.sender, _support, voters[msg.sender].weight);
                        } else {
                            revert("No voting weight");
                        }
                    } else {
                        revert("Already voted");
                    }
                } else {
                    revert("Proposal already executed");
                }
            } else {
                revert("Voting period ended");
            }
        } else {
            revert("Invalid proposal ID");
        }
    }


    function calculateVotingPowerAndUpdateStats(address _voter) public view returns (uint256) {
        return voters[_voter].weight * 2 + voters[_voter].totalVotes;
    }


    function internalQuorumCalculation(uint256 _totalVotes, uint256 _threshold) public pure returns (bool) {
        return _totalVotes >= _threshold;
    }

    function registerVoter(address _voter, uint256 _weight) public onlyAdmin {
        require(!voters[_voter].isRegistered, "Already registered");
        require(_weight > 0, "Weight must be positive");

        voters[_voter] = Voter({
            weight: _weight,
            isRegistered: true,
            totalVotes: 0
        });
    }

    function executeProposal(uint256 _proposalId) public onlyAdmin {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal");
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.deadline, "Voting still active");
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes >= quorum, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;
    }

    function getProposalInfo(uint256 _proposalId) public view returns (
        string memory title,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 deadline,
        bool executed
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed
        );
    }

    function hasVoted(uint256 _proposalId, address _voter) public view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function setQuorum(uint256 _newQuorum) public onlyAdmin {
        require(_newQuorum > 0, "Quorum must be positive");
        quorum = _newQuorum;
    }
}
