
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    address owner;
    uint256 totalProposals;
    uint256 totalVoters;

    struct Proposal {
        uint256 id;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
    }

    struct Voter {
        address voterAddress;
        uint256 votingPower;
        bool isRegistered;
        uint256 registrationTime;
    }

    mapping(uint256 => Proposal) proposals;
    mapping(address => Voter) voters;
    mapping(address => uint256) voterBalances;
    mapping(uint256 => mapping(address => bool)) proposalVoters;

    event ProposalCreated(uint256 proposalId, string description, address proposer);
    event VoteCasted(uint256 proposalId, address voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 proposalId);
    event VoterRegistered(address voter, uint256 votingPower);

    constructor() {
        owner = msg.sender;
        totalProposals = 0;
        totalVoters = 0;
    }

    function registerVoter(uint256 _votingPower) external {

        if (voters[msg.sender].isRegistered == true) {
            revert("Already registered");
        }
        if (_votingPower == 0) {
            revert("Voting power must be greater than 0");
        }
        if (_votingPower > 1000000) {
            revert("Voting power too high");
        }

        voters[msg.sender].voterAddress = msg.sender;
        voters[msg.sender].votingPower = _votingPower;
        voters[msg.sender].isRegistered = true;
        voters[msg.sender].registrationTime = block.timestamp;
        voterBalances[msg.sender] = _votingPower;
        totalVoters = totalVoters + 1;

        emit VoterRegistered(msg.sender, _votingPower);
    }

    function createProposal(string memory _description) external {

        if (voters[msg.sender].isRegistered == false) {
            revert("Not registered voter");
        }
        if (voters[msg.sender].votingPower < 100) {
            revert("Insufficient voting power to create proposal");
        }
        if (bytes(_description).length == 0) {
            revert("Description cannot be empty");
        }
        if (bytes(_description).length > 500) {
            revert("Description too long");
        }

        uint256 proposalId = totalProposals;
        proposals[proposalId].id = proposalId;
        proposals[proposalId].description = _description;
        proposals[proposalId].yesVotes = 0;
        proposals[proposalId].noVotes = 0;
        proposals[proposalId].endTime = block.timestamp + 604800;
        proposals[proposalId].executed = false;
        proposals[proposalId].proposer = msg.sender;

        totalProposals = totalProposals + 1;

        emit ProposalCreated(proposalId, _description, msg.sender);
    }

    function vote(uint256 _proposalId, bool _support) external {

        if (voters[msg.sender].isRegistered == false) {
            revert("Not registered voter");
        }
        if (_proposalId >= totalProposals) {
            revert("Invalid proposal ID");
        }
        if (proposals[_proposalId].endTime < block.timestamp) {
            revert("Voting period ended");
        }
        if (proposals[_proposalId].hasVoted[msg.sender] == true) {
            revert("Already voted");
        }
        if (proposals[_proposalId].executed == true) {
            revert("Proposal already executed");
        }

        uint256 votingPower = voters[msg.sender].votingPower;

        if (_support == true) {
            proposals[_proposalId].yesVotes = proposals[_proposalId].yesVotes + votingPower;
        } else {
            proposals[_proposalId].noVotes = proposals[_proposalId].noVotes + votingPower;
        }

        proposals[_proposalId].hasVoted[msg.sender] = true;
        proposalVoters[_proposalId][msg.sender] = true;

        emit VoteCasted(_proposalId, msg.sender, _support, votingPower);
    }

    function executeProposal(uint256 _proposalId) external {

        if (_proposalId >= totalProposals) {
            revert("Invalid proposal ID");
        }
        if (proposals[_proposalId].endTime > block.timestamp) {
            revert("Voting period not ended");
        }
        if (proposals[_proposalId].executed == true) {
            revert("Proposal already executed");
        }

        uint256 totalVotes = proposals[_proposalId].yesVotes + proposals[_proposalId].noVotes;
        uint256 quorum = (totalVoters * 500000) / 1000000;

        if (totalVotes < quorum) {
            revert("Quorum not reached");
        }

        if (proposals[_proposalId].yesVotes <= proposals[_proposalId].noVotes) {
            revert("Proposal rejected");
        }

        proposals[_proposalId].executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 endTime,
        bool executed,
        address proposer
    ) {

        if (_proposalId >= totalProposals) {
            revert("Invalid proposal ID");
        }

        return (
            proposals[_proposalId].id,
            proposals[_proposalId].description,
            proposals[_proposalId].yesVotes,
            proposals[_proposalId].noVotes,
            proposals[_proposalId].endTime,
            proposals[_proposalId].executed,
            proposals[_proposalId].proposer
        );
    }

    function getVoter(address _voterAddress) external view returns (
        address voterAddress,
        uint256 votingPower,
        bool isRegistered,
        uint256 registrationTime
    ) {
        return (
            voters[_voterAddress].voterAddress,
            voters[_voterAddress].votingPower,
            voters[_voterAddress].isRegistered,
            voters[_voterAddress].registrationTime
        );
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {

        if (_proposalId >= totalProposals) {
            revert("Invalid proposal ID");
        }

        return proposals[_proposalId].hasVoted[_voter];
    }

    function getTotalProposals() external view returns (uint256) {
        return totalProposals;
    }

    function getTotalVoters() external view returns (uint256) {
        return totalVoters;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function updateVotingPower(address _voter, uint256 _newPower) external {

        if (msg.sender != owner) {
            revert("Only owner can update voting power");
        }
        if (voters[_voter].isRegistered == false) {
            revert("Voter not registered");
        }
        if (_newPower == 0) {
            revert("Voting power must be greater than 0");
        }
        if (_newPower > 1000000) {
            revert("Voting power too high");
        }

        voters[_voter].votingPower = _newPower;
        voterBalances[_voter] = _newPower;
    }

    function emergencyStop(uint256 _proposalId) external {

        if (msg.sender != owner) {
            revert("Only owner can emergency stop");
        }
        if (_proposalId >= totalProposals) {
            revert("Invalid proposal ID");
        }
        if (proposals[_proposalId].executed == true) {
            revert("Proposal already executed");
        }

        proposals[_proposalId].endTime = block.timestamp;
    }

    function getProposalVoteCount(uint256 _proposalId) external view returns (uint256 yes, uint256 no, uint256 total) {

        if (_proposalId >= totalProposals) {
            revert("Invalid proposal ID");
        }

        uint256 yesVotes = proposals[_proposalId].yesVotes;
        uint256 noVotes = proposals[_proposalId].noVotes;
        uint256 totalVotes = yesVotes + noVotes;

        return (yesVotes, noVotes, totalVotes);
    }

    function isProposalActive(uint256 _proposalId) external view returns (bool) {

        if (_proposalId >= totalProposals) {
            revert("Invalid proposal ID");
        }

        return (proposals[_proposalId].endTime > block.timestamp && proposals[_proposalId].executed == false);
    }

    function getQuorumRequirement() external view returns (uint256) {
        return (totalVoters * 500000) / 1000000;
    }

    function getMinimumVotingPowerForProposal() external pure returns (uint256) {
        return 100;
    }

    function getVotingPeriod() external pure returns (uint256) {
        return 604800;
    }
}
