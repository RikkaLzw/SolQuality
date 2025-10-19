
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {

    uint256 public constant MAX_PROJECTS = 100;
    uint256 public projectCount = 0;
    uint256 public platformFeePercent = 5;


    struct Project {
        string projectId;
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        uint256 isActive;
        uint256 isCompleted;
        bytes metadata;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(address => uint256[]) public userProjects;

    address public owner;
    uint256 public totalFundsRaised = 0;

    event ProjectCreated(uint256 indexed projectIndex, string projectId, address creator, uint256 goalAmount);
    event ContributionMade(uint256 indexed projectIndex, address contributor, uint256 amount);
    event ProjectCompleted(uint256 indexed projectIndex, uint256 totalRaised);
    event FundsWithdrawn(uint256 indexed projectIndex, address creator, uint256 amount);
    event RefundIssued(uint256 indexed projectIndex, address contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validProject(uint256 _projectIndex) {
        require(_projectIndex < projectCount, "Project does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createProject(
        string memory _projectId,
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays,
        bytes memory _metadata
    ) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(projectCount < MAX_PROJECTS, "Maximum projects reached");


        uint256 deadline = block.timestamp + (uint256(_durationInDays) * uint256(1 days));

        projects[projectCount] = Project({
            projectId: _projectId,
            creator: msg.sender,
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: uint256(1),
            isCompleted: uint256(0),
            metadata: _metadata
        });

        userProjects[msg.sender].push(projectCount);

        emit ProjectCreated(projectCount, _projectId, msg.sender, _goalAmount);


        projectCount = uint256(projectCount + uint256(1));
    }

    function contribute(uint256 _projectIndex) external payable validProject(_projectIndex) {
        Project storage project = projects[_projectIndex];

        require(project.isActive == uint256(1), "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.value > 0, "Contribution must be greater than 0");
        require(project.isCompleted == uint256(0), "Project already completed");

        contributions[_projectIndex][msg.sender] += msg.value;
        project.raisedAmount += msg.value;
        totalFundsRaised += msg.value;

        emit ContributionMade(_projectIndex, msg.sender, msg.value);


        if (project.raisedAmount >= project.goalAmount) {
            project.isCompleted = uint256(1);
            emit ProjectCompleted(_projectIndex, project.raisedAmount);
        }
    }

    function withdrawFunds(uint256 _projectIndex) external validProject(_projectIndex) {
        Project storage project = projects[_projectIndex];

        require(msg.sender == project.creator, "Only project creator can withdraw");
        require(project.isCompleted == uint256(1), "Project not completed");
        require(project.raisedAmount >= project.goalAmount, "Goal not reached");
        require(project.raisedAmount > 0, "No funds to withdraw");

        uint256 platformFee = (project.raisedAmount * platformFeePercent) / uint256(100);
        uint256 creatorAmount = project.raisedAmount - platformFee;

        project.raisedAmount = 0;
        project.isActive = uint256(0);


        (bool success, ) = payable(project.creator).call{value: creatorAmount}("");
        require(success, "Transfer to creator failed");


        if (platformFee > 0) {
            (bool feeSuccess, ) = payable(owner).call{value: platformFee}("");
            require(feeSuccess, "Platform fee transfer failed");
        }

        emit FundsWithdrawn(_projectIndex, project.creator, creatorAmount);
    }

    function requestRefund(uint256 _projectIndex) external validProject(_projectIndex) {
        Project storage project = projects[_projectIndex];

        require(block.timestamp > project.deadline, "Project deadline not reached");
        require(project.raisedAmount < project.goalAmount, "Project goal was reached");
        require(contributions[_projectIndex][msg.sender] > 0, "No contribution found");

        uint256 contributionAmount = contributions[_projectIndex][msg.sender];
        contributions[_projectIndex][msg.sender] = 0;


        project.raisedAmount -= contributionAmount;
        if (project.raisedAmount == 0) {
            project.isActive = uint256(0);
        }

        (bool success, ) = payable(msg.sender).call{value: contributionAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_projectIndex, msg.sender, contributionAmount);
    }

    function getProject(uint256 _projectIndex) external view validProject(_projectIndex) returns (
        string memory projectId,
        address creator,
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 raisedAmount,
        uint256 deadline,
        uint256 isActive,
        uint256 isCompleted,
        bytes memory metadata
    ) {
        Project storage project = projects[_projectIndex];
        return (
            project.projectId,
            project.creator,
            project.title,
            project.description,
            project.goalAmount,
            project.raisedAmount,
            project.deadline,
            project.isActive,
            project.isCompleted,
            project.metadata
        );
    }

    function getUserContribution(uint256 _projectIndex, address _user) external view validProject(_projectIndex) returns (uint256) {
        return contributions[_projectIndex][_user];
    }

    function getUserProjects(address _user) external view returns (uint256[] memory) {
        return userProjects[_user];
    }

    function updatePlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= uint256(10), "Fee cannot exceed 10%");
        platformFeePercent = _newFeePercent;
    }

    function emergencyPause(uint256 _projectIndex) external onlyOwner validProject(_projectIndex) {
        projects[_projectIndex].isActive = uint256(0);
    }

    function emergencyResume(uint256 _projectIndex) external onlyOwner validProject(_projectIndex) {
        require(block.timestamp < projects[_projectIndex].deadline, "Cannot resume expired project");
        projects[_projectIndex].isActive = uint256(1);
    }
}
