
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
        address proposer;
    }

    struct Voter {
        bool hasVoted;
        uint256 votedProposalId;
        uint256 votingPower;
        bool isRegistered;
    }


    Proposal[] public proposals;


    address[] public voterAddresses;

    mapping(address => Voter) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVotedForProposal;

    address public owner;
    uint256 public totalVoters;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;


    uint256 public tempCalculationResult;
    uint256 public tempVoteCount;

    event ProposalCreated(uint256 indexed proposalId, string description, address proposer);
    event VoteCasted(uint256 indexed proposalId, address voter, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Not a registered voter");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalVoters = 0;
        proposalCount = 0;
    }

    function registerVoter(address _voter, uint256 _votingPower) external onlyOwner {
        require(!voters[_voter].isRegistered, "Voter already registered");
        require(_votingPower > 0, "Voting power must be greater than 0");

        voters[_voter] = Voter({
            hasVoted: false,
            votedProposalId: 0,
            votingPower: _votingPower,
            isRegistered: true
        });


        voterAddresses.push(_voter);
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            tempCalculationResult = tempCalculationResult + 1;
        }

        totalVoters++;
    }

    function createProposal(string memory _description) external onlyRegisteredVoter {
        require(bytes(_description).length > 0, "Description cannot be empty");


        uint256 newProposalId = proposalCount;
        proposalCount++;

        Proposal memory newProposal = Proposal({
            id: newProposalId,
            description: _description,
            voteCount: 0,
            deadline: block.timestamp + VOTING_PERIOD,
            executed: false,
            proposer: msg.sender
        });

        proposals.push(newProposal);


        uint256 calculatedDeadline = block.timestamp + VOTING_PERIOD;
        tempCalculationResult = calculatedDeadline;

        emit ProposalCreated(newProposalId, _description, msg.sender);
    }

    function vote(uint256 _proposalId) external onlyRegisteredVoter {

        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(!hasVotedForProposal[_proposalId][msg.sender], "Already voted for this proposal");
        require(block.timestamp < proposals[_proposalId].deadline, "Voting period has ended");


        tempVoteCount = voters[msg.sender].votingPower;


        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].id == _proposalId) {
                proposals[i].voteCount += tempVoteCount;

                tempCalculationResult = proposals[i].voteCount;
                break;
            }
        }

        hasVotedForProposal[_proposalId][msg.sender] = true;


        uint256 voterPower = voters[msg.sender].votingPower;
        tempCalculationResult = voterPower;

        emit VoteCasted(_proposalId, msg.sender, voterPower);
    }

    function executeProposal(uint256 _proposalId) external onlyOwner {

        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(block.timestamp >= proposals[_proposalId].deadline, "Voting period not ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");


        tempVoteCount = 0;


        uint256 totalVotingPower = 0;
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            totalVotingPower += voters[voterAddresses[i]].votingPower;

            tempCalculationResult = totalVotingPower;
        }


        uint256 recalculatedTotalPower = 0;
        for (uint256 j = 0; j < voterAddresses.length; j++) {
            recalculatedTotalPower += voters[voterAddresses[j]].votingPower;
        }


        for (uint256 k = 0; k < proposals.length; k++) {
            if (proposals[k].id == _proposalId) {
                require(proposals[k].voteCount > totalVotingPower / 2, "Proposal did not receive majority votes");
                proposals[k].executed = true;
                break;
            }
        }

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 voteCount,
        uint256 deadline,
        bool executed,
        address proposer
    ) {

        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].id == _proposalId) {
                return (
                    proposals[i].id,
                    proposals[i].description,
                    proposals[i].voteCount,
                    proposals[i].deadline,
                    proposals[i].executed,
                    proposals[i].proposer
                );
            }
        }
        revert("Proposal not found");
    }

    function getAllProposals() external view returns (Proposal[] memory) {
        return proposals;
    }

    function getVoterInfo(address _voter) external view returns (
        bool hasVoted,
        uint256 votedProposalId,
        uint256 votingPower,
        bool isRegistered
    ) {
        Voter memory voter = voters[_voter];
        return (voter.hasVoted, voter.votedProposalId, voter.votingPower, voter.isRegistered);
    }

    function getTotalVotingPower() external view returns (uint256) {

        uint256 totalPower = 0;
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            totalPower += voters[voterAddresses[i]].votingPower;
        }
        return totalPower;
    }
}
