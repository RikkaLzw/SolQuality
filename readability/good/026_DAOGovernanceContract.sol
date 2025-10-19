
pragma solidity ^0.8.19;


contract DAOGovernanceContract {

    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
    }


    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Cancelled
    }


    struct Proposal {
        uint256 proposalId;
        address proposer;
        string title;
        string description;
        address targetContract;
        bytes callData;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) voteChoice;
    }


    IERC20 public governanceToken;
    address public admin;
    uint256 public proposalCount;
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorumVotes;
    uint256 public executionDelay;


    mapping(uint256 => Proposal) public proposals;


    uint256[] public proposalIds;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 choice,
        uint256 weight
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        bool success,
        bytes returnData
    );

    event ProposalCancelled(uint256 indexed proposalId);

    event GovernanceParametersUpdated(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumVotes
    );


    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }


    constructor(
        address _governanceToken,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumVotes
    ) {
        require(_governanceToken != address(0), "Invalid governance token address");
        require(_votingPeriod > 0, "Voting period must be greater than 0");
        require(_proposalThreshold > 0, "Proposal threshold must be greater than 0");
        require(_quorumVotes > 0, "Quorum votes must be greater than 0");

        governanceToken = IERC20(_governanceToken);
        admin = msg.sender;
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumVotes = _quorumVotes;
        executionDelay = 2 days;
    }


    function createProposal(
        string memory title,
        string memory description,
        address targetContract,
        bytes memory callData
    ) external returns (uint256 proposalId) {

        require(
            governanceToken.balanceOf(msg.sender) >= proposalThreshold,
            "Insufficient tokens to create proposal"
        );

        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");


        proposalCount++;
        proposalId = proposalCount;


        uint256 startTime = block.timestamp + votingDelay;
        uint256 endTime = startTime + votingPeriod;


        Proposal storage newProposal = proposals[proposalId];
        newProposal.proposalId = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.targetContract = targetContract;
        newProposal.callData = callData;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;
        newProposal.executed = false;
        newProposal.cancelled = false;


        proposalIds.push(proposalId);


        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            description,
            startTime,
            endTime
        );

        return proposalId;
    }


    function castVote(uint256 proposalId, uint8 choice) external validProposal(proposalId) {
        require(choice >= 1 && choice <= 3, "Invalid vote choice");

        Proposal storage proposal = proposals[proposalId];


        require(block.timestamp >= proposal.startTime, "Voting has not started yet");
        require(block.timestamp <= proposal.endTime, "Voting has ended");
        require(!proposal.cancelled, "Proposal has been cancelled");
        require(!proposal.hasVoted[msg.sender], "Already voted");


        uint256 voterWeight = governanceToken.balanceOf(msg.sender);
        require(voterWeight > 0, "No voting power");


        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = choice;


        if (choice == 1) {
            proposal.forVotes += voterWeight;
        } else if (choice == 2) {
            proposal.againstVotes += voterWeight;
        } else {
            proposal.abstainVotes += voterWeight;
        }


        emit VoteCast(proposalId, msg.sender, choice, voterWeight);
    }


    function executeProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting is still active");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal has been cancelled");


        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Succeeded, "Proposal did not succeed");


        require(
            block.timestamp >= proposal.endTime + executionDelay,
            "Execution delay not met"
        );


        proposal.executed = true;


        bool success = false;
        bytes memory returnData;

        if (proposal.targetContract != address(0)) {
            (success, returnData) = proposal.targetContract.call(proposal.callData);
        } else {
            success = true;
        }


        emit ProposalExecuted(proposalId, success, returnData);
    }


    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "Only proposer or admin can cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.cancelled, "Proposal already cancelled");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }


    function getProposalState(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }


        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;

        if (totalVotes < quorumVotes) {
            return ProposalState.Defeated;
        }

        if (proposal.forVotes > proposal.againstVotes) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }


    function getProposalDetails(uint256 proposalId) external view validProposal(proposalId) returns (
        address proposer,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        ProposalState state
    ) {
        Proposal storage proposal = proposals[proposalId];

        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            getProposalState(proposalId)
        );
    }


    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }


    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId) returns (uint8) {
        return proposals[proposalId].voteChoice[voter];
    }


    function getAllProposalIds() external view returns (uint256[] memory) {
        return proposalIds;
    }


    function updateGovernanceParameters(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumVotes
    ) external onlyAdmin {
        require(_votingPeriod > 0, "Voting period must be greater than 0");
        require(_proposalThreshold > 0, "Proposal threshold must be greater than 0");
        require(_quorumVotes > 0, "Quorum votes must be greater than 0");

        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumVotes = _quorumVotes;

        emit GovernanceParametersUpdated(_votingDelay, _votingPeriod, _proposalThreshold, _quorumVotes);
    }


    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid new admin address");
        admin = newAdmin;
    }


    function emergencyPause() external onlyAdmin {


    }
}
