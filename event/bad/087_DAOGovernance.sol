
pragma solidity ^0.8.0;

contract DAOGovernance {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => bool) public members;

    uint256 public proposalCount;
    uint256 public totalVotingPower;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;
    address public admin;

    event ProposalCreated(uint256 proposalId, address proposer);
    event VoteCast(address voter, uint256 proposalId, bool support);
    event ProposalExecuted(uint256 proposalId);
    event MemberAdded(address member);

    error InvalidProposal();
    error NotAuthorized();
    error VotingEnded();

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender]);
        _;
    }

    constructor() {
        admin = msg.sender;
        members[msg.sender] = true;
        votingPower[msg.sender] = 1000;
        totalVotingPower = 1000;
    }

    function addMember(address _member, uint256 _votingPower) external onlyAdmin {
        require(_member != address(0));
        require(_votingPower >= MIN_VOTING_POWER);

        members[_member] = true;
        votingPower[_member] = _votingPower;
        totalVotingPower += _votingPower;

        emit MemberAdded(_member);
    }

    function createProposal(string memory _description) external onlyMember {
        require(bytes(_description).length > 0);
        require(votingPower[msg.sender] >= MIN_VOTING_POWER);

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.description = _description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;

        emit ProposalCreated(proposalCount, msg.sender);
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];

        require(_proposalId > 0 && _proposalId <= proposalCount);
        require(block.timestamp >= proposal.startTime);
        require(block.timestamp <= proposal.endTime);
        require(!proposal.hasVoted[msg.sender]);

        proposal.hasVoted[msg.sender] = true;

        if (_support) {
            proposal.votesFor += votingPower[msg.sender];
        } else {
            proposal.votesAgainst += votingPower[msg.sender];
        }

        emit VoteCast(msg.sender, _proposalId, _support);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(_proposalId > 0 && _proposalId <= proposalCount);
        require(block.timestamp > proposal.endTime);
        require(!proposal.executed);
        require(proposal.votesFor > proposal.votesAgainst);
        require(proposal.votesFor > totalVotingPower / 2);

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount);

        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount);
        return proposals[_proposalId].hasVoted[_voter];
    }

    function updateVotingPower(address _member, uint256 _newPower) external onlyAdmin {
        require(members[_member]);
        require(_newPower >= MIN_VOTING_POWER);

        totalVotingPower = totalVotingPower - votingPower[_member] + _newPower;
        votingPower[_member] = _newPower;
    }

    function removeMember(address _member) external onlyAdmin {
        require(members[_member]);
        require(_member != admin);

        totalVotingPower -= votingPower[_member];
        members[_member] = false;
        votingPower[_member] = 0;
    }
}
