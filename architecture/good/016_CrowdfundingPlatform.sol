
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant PLATFORM_FEE_RATE = 25;
    uint256 public constant MIN_FUNDING_DURATION = 1 days;
    uint256 public constant MAX_FUNDING_DURATION = 365 days;
    uint256 public constant MIN_FUNDING_GOAL = 0.01 ether;


    enum ProjectStatus {
        Active,
        Successful,
        Failed,
        Withdrawn
    }


    struct Project {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        ProjectStatus status;
        bool exists;
    }

    struct Contribution {
        uint256 amount;
        uint256 timestamp;
        bool refunded;
    }


    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(uint256 => address[]) public projectContributors;

    uint256 public projectCounter;
    uint256 public totalPlatformFees;


    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event ProjectFunded(uint256 indexed projectId, uint256 totalAmount);
    event ProjectFailed(uint256 indexed projectId);
    event FundsWithdrawn(uint256 indexed projectId, uint256 amount);
    event RefundClaimed(uint256 indexed projectId, address indexed contributor, uint256 amount);


    modifier projectExists(uint256 _projectId) {
        require(projects[_projectId].exists, "Project does not exist");
        _;
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(msg.sender == projects[_projectId].creator, "Only project creator can call this");
        _;
    }

    modifier projectActive(uint256 _projectId) {
        require(projects[_projectId].status == ProjectStatus.Active, "Project is not active");
        _;
    }

    modifier validFundingAmount() {
        require(msg.value > 0, "Contribution must be greater than 0");
        _;
    }

    modifier deadlineNotPassed(uint256 _projectId) {
        require(block.timestamp <= projects[_projectId].deadline, "Project deadline has passed");
        _;
    }

    modifier deadlinePassed(uint256 _projectId) {
        require(block.timestamp > projects[_projectId].deadline, "Project deadline has not passed");
        _;
    }

    constructor() {}


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_goalAmount >= MIN_FUNDING_GOAL, "Goal amount too low");
        require(
            _durationInDays >= MIN_FUNDING_DURATION / 1 days &&
            _durationInDays <= MAX_FUNDING_DURATION / 1 days,
            "Invalid funding duration"
        );

        uint256 projectId = projectCounter++;
        uint256 deadline = block.timestamp.add(_durationInDays.mul(1 days));

        projects[projectId] = Project({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            exists: true
        });

        emit ProjectCreated(projectId, msg.sender, _title, _goalAmount, deadline);
        return projectId;
    }


    function contribute(uint256 _projectId)
        external
        payable
        nonReentrant
        projectExists(_projectId)
        projectActive(_projectId)
        validFundingAmount()
        deadlineNotPassed(_projectId)
    {
        Project storage project = projects[_projectId];


        if (contributions[_projectId][msg.sender].amount == 0) {
            projectContributors[_projectId].push(msg.sender);
        }

        contributions[_projectId][msg.sender].amount = contributions[_projectId][msg.sender].amount.add(msg.value);
        contributions[_projectId][msg.sender].timestamp = block.timestamp;

        project.raisedAmount = project.raisedAmount.add(msg.value);

        emit ContributionMade(_projectId, msg.sender, msg.value);


        if (project.raisedAmount >= project.goalAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectFunded(_projectId, project.raisedAmount);
        }
    }


    function finalizeProject(uint256 _projectId)
        external
        projectExists(_projectId)
        projectActive(_projectId)
        deadlinePassed(_projectId)
    {
        Project storage project = projects[_projectId];

        if (project.raisedAmount >= project.goalAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectFunded(_projectId, project.raisedAmount);
        } else {
            project.status = ProjectStatus.Failed;
            emit ProjectFailed(_projectId);
        }
    }


    function withdrawFunds(uint256 _projectId)
        external
        nonReentrant
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
    {
        Project storage project = projects[_projectId];
        require(project.status == ProjectStatus.Successful, "Project must be successful");
        require(project.raisedAmount > 0, "No funds to withdraw");

        uint256 platformFee = _calculatePlatformFee(project.raisedAmount);
        uint256 creatorAmount = project.raisedAmount.sub(platformFee);

        project.status = ProjectStatus.Withdrawn;
        totalPlatformFees = totalPlatformFees.add(platformFee);


        project.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_projectId, creatorAmount);
    }


    function claimRefund(uint256 _projectId)
        external
        nonReentrant
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];
        require(project.status == ProjectStatus.Failed, "Project must be failed");

        Contribution storage contribution = contributions[_projectId][msg.sender];
        require(contribution.amount > 0, "No contribution found");
        require(!contribution.refunded, "Refund already claimed");

        uint256 refundAmount = contribution.amount;
        contribution.refunded = true;

        payable(msg.sender).transfer(refundAmount);

        emit RefundClaimed(_projectId, msg.sender, refundAmount);
    }


    function withdrawPlatformFees() external onlyOwner nonReentrant {
        require(totalPlatformFees > 0, "No platform fees to withdraw");

        uint256 amount = totalPlatformFees;
        totalPlatformFees = 0;

        payable(owner()).transfer(amount);
    }


    function getProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            ProjectStatus status
        )
    {
        Project storage project = projects[_projectId];
        return (
            project.creator,
            project.title,
            project.description,
            project.goalAmount,
            project.raisedAmount,
            project.deadline,
            project.status
        );
    }

    function getContribution(uint256 _projectId, address _contributor)
        external
        view
        returns (uint256 amount, uint256 timestamp, bool refunded)
    {
        Contribution storage contribution = contributions[_projectId][_contributor];
        return (contribution.amount, contribution.timestamp, contribution.refunded);
    }

    function getProjectContributors(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (address[] memory)
    {
        return projectContributors[_projectId];
    }

    function getProjectContributorCount(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (uint256)
    {
        return projectContributors[_projectId].length;
    }


    function _calculatePlatformFee(uint256 _amount) internal pure returns (uint256) {
        return _amount.mul(PLATFORM_FEE_RATE).div(1000);
    }


    function emergencyPause() external onlyOwner {


    }

    receive() external payable {
        revert("Direct payments not allowed");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
