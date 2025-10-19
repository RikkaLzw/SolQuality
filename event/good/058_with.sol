
pragma solidity ^0.8.0;


contract DAOGovernance {

    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
    }


    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }


    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }


    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
    }


    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 17280;
    uint256 public constant PROPOSAL_THRESHOLD = 100000e18;
    uint256 public constant QUORUM_VOTES = 400000e18;
    uint256 public constant TIMELOCK_DELAY = 2 days;


    IERC20 public immutable governanceToken;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(bytes32 => bool) public queuedTransactions;
    address public admin;
    address public pendingAdmin;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    event ProposalCanceled(uint256 indexed proposalId);

    event ProposalQueued(uint256 indexed proposalId, uint256 eta);

    event ProposalExecuted(uint256 indexed proposalId);

    event NewPendingAdmin(address indexed oldPendingAdmin, address indexed newPendingAdmin);

    event NewAdmin(address indexed oldAdmin, address indexed newAdmin);

    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );


    modifier onlyAdmin() {
        require(msg.sender == admin, "DAOGovernance: caller is not the admin");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == address(this), "DAOGovernance: caller is not the governance contract");
        _;
    }


    constructor(address _governanceToken, address _admin) {
        require(_governanceToken != address(0), "DAOGovernance: invalid governance token address");
        require(_admin != address(0), "DAOGovernance: invalid admin address");

        governanceToken = IERC20(_governanceToken);
        admin = _admin;
    }


    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(
            governanceToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD,
            "DAOGovernance: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
            targets.length == signatures.length &&
            targets.length == calldatas.length,
            "DAOGovernance: proposal function information arity mismatch"
        );
        require(targets.length != 0, "DAOGovernance: must provide actions");
        require(targets.length <= 10, "DAOGovernance: too many actions");

        uint256 startBlock = block.number + VOTING_DELAY;
        uint256 endBlock = startBlock + VOTING_PERIOD;

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );

        return proposalId;
    }


    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "DAOGovernance: proposal can only be queued if it is succeeded"
        );

        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + TIMELOCK_DELAY;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }

        emit ProposalQueued(proposalId, eta);
    }


    function execute(uint256 proposalId) external payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "DAOGovernance: proposal can only be executed if it is queued"
        );

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                block.timestamp + TIMELOCK_DELAY
            );
        }

        emit ProposalExecuted(proposalId);
    }


    function cancel(uint256 proposalId) external {
        ProposalState currentState = state(proposalId);
        require(
            currentState != ProposalState.Executed,
            "DAOGovernance: cannot cancel executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer ||
            governanceToken.balanceOf(proposal.proposer) < PROPOSAL_THRESHOLD,
            "DAOGovernance: proposer above threshold"
        );

        proposal.canceled = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                block.timestamp + TIMELOCK_DELAY
            );
        }

        emit ProposalCanceled(proposalId);
    }


    function castVote(uint256 proposalId, uint8 support) external {
        return _castVote(msg.sender, proposalId, support, "");
    }


    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        return _castVote(msg.sender, proposalId, support, reason);
    }


    function _castVote(
        address voter,
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) internal {
        require(
            state(proposalId) == ProposalState.Active,
            "DAOGovernance: voting is closed"
        );
        require(support <= 2, "DAOGovernance: invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(!receipt.hasVoted, "DAOGovernance: voter already voted");

        uint256 votes = governanceToken.balanceOf(voter);
        require(votes > 0, "DAOGovernance: voter has no voting power");

        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes, reason);
    }


    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId <= proposalCount && proposalId > 0, "DAOGovernance: invalid proposal id");

        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < QUORUM_VOTES) {
            return ProposalState.Defeated;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= block.timestamp + TIMELOCK_DELAY) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Succeeded;
        }
    }


    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }


    function setPendingAdmin(address newPendingAdmin) external onlyAdmin {
        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }


    function acceptAdmin() external {
        require(
            msg.sender == pendingAdmin && msg.sender != address(0),
            "DAOGovernance: caller must be pending admin"
        );

        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        admin = pendingAdmin;
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }


    function _queueOrRevert(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            eta >= block.timestamp + TIMELOCK_DELAY,
            "DAOGovernance: estimated execution block must satisfy delay"
        );

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(!queuedTransactions[txHash], "DAOGovernance: identical proposal action already queued");

        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
    }


    function _cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }


    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "DAOGovernance: transaction hasn't been queued");
        require(block.timestamp >= eta, "DAOGovernance: transaction hasn't surpassed time lock");
        require(block.timestamp <= eta + 14 days, "DAOGovernance: transaction is stale");

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "DAOGovernance: transaction execution reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }


    receive() external payable {}
}
