
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        bytes32 id;
        string title;
        string description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) votes;
    }

    struct Member {
        bool isActive;
        uint256 votingPower;
        uint256 joinTime;
    }

    mapping(bytes32 => Proposal) public proposals;
    mapping(address => Member) public members;

    bytes32[] public proposalIds;
    address[] public memberAddresses;

    address public admin;
    uint256 public totalVotingPower;
    uint256 public proposalCounter;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1;
    uint256 public constant QUORUM_PERCENTAGE = 51;

    event ProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        bytes32 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 votingPower
    );

    event ProposalExecuted(bytes32 indexed proposalId);
    event ProposalCanceled(bytes32 indexed proposalId);
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);
    event VotingPowerUpdated(address indexed member, uint256 newVotingPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "Only active members can perform this action");
        require(members[msg.sender].votingPower >= MIN_VOTING_POWER, "Insufficient voting power");
        _;
    }

    modifier proposalExists(bytes32 _proposalId) {
        require(proposals[_proposalId].proposer != address(0), "Proposal does not exist");
        _;
    }

    modifier proposalActive(bytes32 _proposalId) {
        require(block.timestamp >= proposals[_proposalId].startTime, "Proposal not started");
        require(block.timestamp <= proposals[_proposalId].endTime, "Proposal ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        require(!proposals[_proposalId].canceled, "Proposal canceled");
        _;
    }

    constructor() {
        admin = msg.sender;
        members[admin] = Member({
            isActive: true,
            votingPower: 100,
            joinTime: block.timestamp
        });
        memberAddresses.push(admin);
        totalVotingPower = 100;
    }

    function addMember(address _member, uint256 _votingPower) external onlyAdmin {
        require(_member != address(0), "Invalid member address");
        require(_votingPower >= MIN_VOTING_POWER, "Voting power too low");
        require(!members[_member].isActive, "Member already exists");

        members[_member] = Member({
            isActive: true,
            votingPower: _votingPower,
            joinTime: block.timestamp
        });

        memberAddresses.push(_member);
        totalVotingPower += _votingPower;

        emit MemberAdded(_member, _votingPower);
    }

    function removeMember(address _member) external onlyAdmin {
        require(members[_member].isActive, "Member not active");
        require(_member != admin, "Cannot remove admin");

        totalVotingPower -= members[_member].votingPower;
        members[_member].isActive = false;
        members[_member].votingPower = 0;


        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (memberAddresses[i] == _member) {
                memberAddresses[i] = memberAddresses[memberAddresses.length - 1];
                memberAddresses.pop();
                break;
            }
        }

        emit MemberRemoved(_member);
    }

    function updateVotingPower(address _member, uint256 _newVotingPower) external onlyAdmin {
        require(members[_member].isActive, "Member not active");
        require(_newVotingPower >= MIN_VOTING_POWER, "Voting power too low");

        uint256 oldPower = members[_member].votingPower;
        members[_member].votingPower = _newVotingPower;

        if (_newVotingPower > oldPower) {
            totalVotingPower += (_newVotingPower - oldPower);
        } else {
            totalVotingPower -= (oldPower - _newVotingPower);
        }

        emit VotingPowerUpdated(_member, _newVotingPower);
    }

    function createProposal(
        string calldata _title,
        string calldata _description
    ) external onlyActiveMember returns (bytes32) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        proposalCounter++;
        bytes32 proposalId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            proposalCounter
        ));

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;
        newProposal.executed = false;
        newProposal.canceled = false;

        proposalIds.push(proposalId);

        emit ProposalCreated(proposalId, msg.sender, _title, startTime, endTime);

        return proposalId;
    }

    function vote(
        bytes32 _proposalId,
        uint8 _support
    ) external onlyActiveMember proposalExists(_proposalId) proposalActive(_proposalId) {
        require(_support <= 2, "Invalid vote option");
        require(!proposals[_proposalId].hasVoted[msg.sender], "Already voted");

        Proposal storage proposal = proposals[_proposalId];
        uint256 votingPower = members[msg.sender].votingPower;

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = _support;

        if (_support == 0) {
            proposal.againstVotes += votingPower;
        } else if (_support == 1) {
            proposal.forVotes += votingPower;
        } else {
            proposal.abstainVotes += votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
    }

    function executeProposal(bytes32 _proposalId) external proposalExists(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal canceled");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 requiredQuorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        require(totalVotes >= requiredQuorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function cancelProposal(bytes32 _proposalId) external proposalExists(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "Only proposer or admin can cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.canceled, "Proposal already canceled");

        proposal.canceled = true;

        emit ProposalCanceled(_proposalId);
    }

    function getProposalInfo(bytes32 _proposalId) external view proposalExists(_proposalId) returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        bool canceled
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.canceled
        );
    }

    function hasVoted(bytes32 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getVote(bytes32 _proposalId, address _voter) external view returns (uint8) {
        require(proposals[_proposalId].hasVoted[_voter], "Voter has not voted");
        return proposals[_proposalId].votes[_voter];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    function getMemberCount() external view returns (uint256) {
        return memberAddresses.length;
    }

    function isMemberActive(address _member) external view returns (bool) {
        return members[_member].isActive;
    }

    function getMemberVotingPower(address _member) external view returns (uint256) {
        return members[_member].votingPower;
    }
}
