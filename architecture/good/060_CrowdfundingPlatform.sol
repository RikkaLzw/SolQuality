
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant MIN_FUNDING_DURATION = 1 days;
    uint256 public constant MAX_FUNDING_DURATION = 365 days;
    uint256 public constant MIN_FUNDING_GOAL = 0.1 ether;


    enum ProjectStatus {
        Active,
        Successful,
        Failed,
        Cancelled
    }


    struct Project {
        address payable creator;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 fundingDeadline;
        uint256 totalFunded;
        ProjectStatus status;
        bool fundsWithdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    struct ContributorInfo {
        uint256 amount;
        bool refunded;
    }


    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => ContributorInfo)) public contributorDetails;
    uint256 public projectCounter;
    uint256 public platformBalance;


    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        string title,
        uint256 fundingGoal,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event ProjectFunded(uint256 indexed projectId, uint256 totalAmount);

    event FundsWithdrawn(
        uint256 indexed projectId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    event RefundIssued(
        uint256 indexed projectId,
        address indexed contributor,
        uint256 amount
    );

    event ProjectCancelled(uint256 indexed projectId);


    modifier validProject(uint256 _projectId) {
        require(_projectId < projectCounter, "Project does not exist");
        _;
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(
            projects[_projectId].creator == msg.sender,
            "Only project creator can perform this action"
        );
        _;
    }

    modifier projectActive(uint256 _projectId) {
        require(
            projects[_projectId].status == ProjectStatus.Active,
            "Project is not active"
        );
        require(
            block.timestamp <= projects[_projectId].fundingDeadline,
            "Funding period has ended"
        );
        _;
    }

    modifier projectEnded(uint256 _projectId) {
        require(
            block.timestamp > projects[_projectId].fundingDeadline ||
            projects[_projectId].status != ProjectStatus.Active,
            "Project is still active"
        );
        _;
    }

    constructor() {}


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _duration
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_fundingGoal >= MIN_FUNDING_GOAL, "Funding goal too low");
        require(
            _duration >= MIN_FUNDING_DURATION && _duration <= MAX_FUNDING_DURATION,
            "Invalid funding duration"
        );

        uint256 projectId = projectCounter++;
        Project storage newProject = projects[projectId];

        newProject.creator = payable(msg.sender);
        newProject.title = _title;
        newProject.description = _description;
        newProject.fundingGoal = _fundingGoal;
        newProject.fundingDeadline = block.timestamp.add(_duration);
        newProject.status = ProjectStatus.Active;

        emit ProjectCreated(
            projectId,
            msg.sender,
            _title,
            _fundingGoal,
            newProject.fundingDeadline
        );

        return projectId;
    }


    function contribute(uint256 _projectId)
        external
        payable
        validProject(_projectId)
        projectActive(_projectId)
        nonReentrant
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Project storage project = projects[_projectId];
        require(
            project.creator != msg.sender,
            "Project creator cannot contribute to own project"
        );


        if (contributorDetails[_projectId][msg.sender].amount == 0) {
            project.contributors.push(msg.sender);
        }

        project.contributions[msg.sender] = project.contributions[msg.sender].add(msg.value);
        contributorDetails[_projectId][msg.sender].amount =
            contributorDetails[_projectId][msg.sender].amount.add(msg.value);

        project.totalFunded = project.totalFunded.add(msg.value);

        emit ContributionMade(_projectId, msg.sender, msg.value);


        if (project.totalFunded >= project.fundingGoal) {
            project.status = ProjectStatus.Successful;
            emit ProjectFunded(_projectId, project.totalFunded);
        }
    }


    function withdrawFunds(uint256 _projectId)
        external
        validProject(_projectId)
        onlyProjectCreator(_projectId)
        projectEnded(_projectId)
        nonReentrant
    {
        Project storage project = projects[_projectId];
        require(
            project.status == ProjectStatus.Successful,
            "Project was not successful"
        );
        require(!project.fundsWithdrawn, "Funds already withdrawn");

        project.fundsWithdrawn = true;

        uint256 totalAmount = project.totalFunded;
        uint256 platformFee = totalAmount.mul(PLATFORM_FEE_RATE).div(10000);
        uint256 creatorAmount = totalAmount.sub(platformFee);

        platformBalance = platformBalance.add(platformFee);

        (bool success, ) = project.creator.call{value: creatorAmount}("");
        require(success, "Transfer to creator failed");

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
    }


    function requestRefund(uint256 _projectId)
        external
        validProject(_projectId)
        projectEnded(_projectId)
        nonReentrant
    {
        Project storage project = projects[_projectId];


        if (block.timestamp > project.fundingDeadline &&
            project.totalFunded < project.fundingGoal &&
            project.status == ProjectStatus.Active) {
            project.status = ProjectStatus.Failed;
        }

        require(
            project.status == ProjectStatus.Failed ||
            project.status == ProjectStatus.Cancelled,
            "Refunds not available for this project"
        );

        ContributorInfo storage contributorInfo = contributorDetails[_projectId][msg.sender];
        require(contributorInfo.amount > 0, "No contribution found");
        require(!contributorInfo.refunded, "Already refunded");

        contributorInfo.refunded = true;
        uint256 refundAmount = contributorInfo.amount;

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_projectId, msg.sender, refundAmount);
    }


    function cancelProject(uint256 _projectId)
        external
        validProject(_projectId)
        onlyProjectCreator(_projectId)
        projectActive(_projectId)
    {
        projects[_projectId].status = ProjectStatus.Cancelled;
        emit ProjectCancelled(_projectId);
    }


    function withdrawPlatformFees() external onlyOwner nonReentrant {
        require(platformBalance > 0, "No fees to withdraw");

        uint256 amount = platformBalance;
        platformBalance = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Platform fee withdrawal failed");
    }


    function getProjectDetails(uint256 _projectId)
        external
        view
        validProject(_projectId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 fundingGoal,
            uint256 fundingDeadline,
            uint256 totalFunded,
            ProjectStatus status,
            bool fundsWithdrawn
        )
    {
        Project storage project = projects[_projectId];
        return (
            project.creator,
            project.title,
            project.description,
            project.fundingGoal,
            project.fundingDeadline,
            project.totalFunded,
            project.status,
            project.fundsWithdrawn
        );
    }

    function getContributorInfo(uint256 _projectId, address _contributor)
        external
        view
        validProject(_projectId)
        returns (uint256 amount, bool refunded)
    {
        ContributorInfo storage info = contributorDetails[_projectId][_contributor];
        return (info.amount, info.refunded);
    }

    function getProjectContributors(uint256 _projectId)
        external
        view
        validProject(_projectId)
        returns (address[] memory)
    {
        return projects[_projectId].contributors;
    }

    function getContribution(uint256 _projectId, address _contributor)
        external
        view
        validProject(_projectId)
        returns (uint256)
    {
        return projects[_projectId].contributions[_contributor];
    }

    function isProjectSuccessful(uint256 _projectId)
        external
        view
        validProject(_projectId)
        returns (bool)
    {
        Project storage project = projects[_projectId];
        return project.totalFunded >= project.fundingGoal;
    }

    function getProjectProgress(uint256 _projectId)
        external
        view
        validProject(_projectId)
        returns (uint256 percentage)
    {
        Project storage project = projects[_projectId];
        if (project.fundingGoal == 0) return 0;
        return project.totalFunded.mul(100).div(project.fundingGoal);
    }

    function getTimeRemaining(uint256 _projectId)
        external
        view
        validProject(_projectId)
        returns (uint256)
    {
        Project storage project = projects[_projectId];
        if (block.timestamp >= project.fundingDeadline) return 0;
        return project.fundingDeadline.sub(block.timestamp);
    }


    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0, "No balance to withdraw");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Emergency withdrawal failed");
    }

    receive() external payable {
        revert("Direct payments not accepted");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
