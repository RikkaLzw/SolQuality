
pragma solidity ^0.8.19;


contract CrowdfundingPlatform {


    enum ProjectStatus {
        Active,
        Successful,
        Failed,
        Withdrawn
    }


    struct Project {
        uint256 projectId;
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        ProjectStatus status;
        bool exists;
    }


    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
    }


    mapping(uint256 => Project) public projects;
    mapping(uint256 => Investment[]) public projectInvestments;
    mapping(uint256 => mapping(address => uint256)) public investorContributions;
    mapping(address => uint256[]) public creatorProjects;
    mapping(address => uint256[]) public investorProjects;

    uint256 public nextProjectId;
    uint256 public totalProjectsCreated;
    uint256 public totalAmountRaised;


    uint256 public platformFeePercentage;
    address payable public platformOwner;
    uint256 public collectedFees;


    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );

    event InvestmentMade(
        uint256 indexed projectId,
        address indexed investor,
        uint256 amount,
        uint256 totalRaised
    );

    event ProjectStatusChanged(
        uint256 indexed projectId,
        ProjectStatus oldStatus,
        ProjectStatus newStatus
    );

    event FundsWithdrawn(
        uint256 indexed projectId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    event RefundIssued(
        uint256 indexed projectId,
        address indexed investor,
        uint256 amount
    );

    event PlatformFeeChanged(
        uint256 oldFeePercentage,
        uint256 newFeePercentage
    );


    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier projectExists(uint256 _projectId) {
        require(projects[_projectId].exists, "Project does not exist");
        _;
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(projects[_projectId].creator == msg.sender, "Only project creator can call this function");
        _;
    }


    constructor(uint256 _platformFeePercentage) {
        require(_platformFeePercentage <= 1000, "Platform fee cannot exceed 10%");

        platformOwner = payable(msg.sender);
        platformFeePercentage = _platformFeePercentage;
        nextProjectId = 1;
        totalProjectsCreated = 0;
        totalAmountRaised = 0;
        collectedFees = 0;
    }


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than zero");
        require(_durationInDays > 0 && _durationInDays <= 365, "Duration must be between 1 and 365 days");

        uint256 projectId = nextProjectId;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        projects[projectId] = Project({
            projectId: projectId,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            exists: true
        });

        creatorProjects[msg.sender].push(projectId);

        nextProjectId++;
        totalProjectsCreated++;

        emit ProjectCreated(projectId, msg.sender, _title, _goalAmount, deadline);
    }


    function investInProject(uint256 _projectId) external payable projectExists(_projectId) {
        Project storage project = projects[_projectId];

        require(msg.value > 0, "Investment amount must be greater than zero");
        require(project.status == ProjectStatus.Active, "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.sender != project.creator, "Creator cannot invest in their own project");


        Investment memory newInvestment = Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });

        projectInvestments[_projectId].push(newInvestment);
        investorContributions[_projectId][msg.sender] += msg.value;
        project.raisedAmount += msg.value;
        totalAmountRaised += msg.value;


        if (investorContributions[_projectId][msg.sender] == msg.value) {
            investorProjects[msg.sender].push(_projectId);
        }

        emit InvestmentMade(_projectId, msg.sender, msg.value, project.raisedAmount);


        if (project.raisedAmount >= project.goalAmount) {
            ProjectStatus oldStatus = project.status;
            project.status = ProjectStatus.Successful;
            emit ProjectStatusChanged(_projectId, oldStatus, ProjectStatus.Successful);
        }
    }


    function withdrawFunds(uint256 _projectId) external projectExists(_projectId) onlyProjectCreator(_projectId) {
        Project storage project = projects[_projectId];

        require(project.status == ProjectStatus.Successful, "Project must be successful to withdraw funds");
        require(project.raisedAmount > 0, "No funds to withdraw");

        uint256 totalAmount = project.raisedAmount;
        uint256 platformFee = (totalAmount * platformFeePercentage) / 10000;
        uint256 creatorAmount = totalAmount - platformFee;


        ProjectStatus oldStatus = project.status;
        project.status = ProjectStatus.Withdrawn;
        collectedFees += platformFee;


        project.raisedAmount = 0;

        emit ProjectStatusChanged(_projectId, oldStatus, ProjectStatus.Withdrawn);
        emit FundsWithdrawn(_projectId, msg.sender, creatorAmount, platformFee);


        (bool success, ) = project.creator.call{value: creatorAmount}("");
        require(success, "Transfer to creator failed");


        if (platformFee > 0) {
            (bool feeSuccess, ) = platformOwner.call{value: platformFee}("");
            require(feeSuccess, "Platform fee transfer failed");
        }
    }


    function requestRefund(uint256 _projectId) external projectExists(_projectId) {
        Project storage project = projects[_projectId];

        require(block.timestamp >= project.deadline, "Project deadline has not passed yet");
        require(project.raisedAmount < project.goalAmount, "Project was successful, no refund available");
        require(investorContributions[_projectId][msg.sender] > 0, "No contribution found for this investor");


        if (project.status == ProjectStatus.Active) {
            ProjectStatus oldStatus = project.status;
            project.status = ProjectStatus.Failed;
            emit ProjectStatusChanged(_projectId, oldStatus, ProjectStatus.Failed);
        }

        require(project.status == ProjectStatus.Failed, "Project is not in failed state");

        uint256 refundAmount = investorContributions[_projectId][msg.sender];
        investorContributions[_projectId][msg.sender] = 0;
        project.raisedAmount -= refundAmount;

        emit RefundIssued(_projectId, msg.sender, refundAmount);


        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");
    }


    function updateProjectStatus(uint256 _projectId) external projectExists(_projectId) {
        Project storage project = projects[_projectId];

        if (project.status == ProjectStatus.Active && block.timestamp >= project.deadline) {
            if (project.raisedAmount < project.goalAmount) {
                ProjectStatus oldStatus = project.status;
                project.status = ProjectStatus.Failed;
                emit ProjectStatusChanged(_projectId, oldStatus, ProjectStatus.Failed);
            }
        }
    }


    function getProjectDetails(uint256 _projectId) external view projectExists(_projectId) returns (
        uint256 projectId,
        address creator,
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 raisedAmount,
        uint256 deadline,
        ProjectStatus status
    ) {
        Project storage project = projects[_projectId];
        return (
            project.projectId,
            project.creator,
            project.title,
            project.description,
            project.goalAmount,
            project.raisedAmount,
            project.deadline,
            project.status
        );
    }


    function getProjectInvestmentCount(uint256 _projectId) external view projectExists(_projectId) returns (uint256) {
        return projectInvestments[_projectId].length;
    }


    function getProjectInvestment(uint256 _projectId, uint256 _index) external view projectExists(_projectId) returns (
        address investor,
        uint256 amount,
        uint256 timestamp
    ) {
        require(_index < projectInvestments[_projectId].length, "Investment index out of bounds");
        Investment storage investment = projectInvestments[_projectId][_index];
        return (investment.investor, investment.amount, investment.timestamp);
    }


    function getCreatorProjects(address _creator) external view returns (uint256[] memory) {
        return creatorProjects[_creator];
    }


    function getInvestorProjects(address _investor) external view returns (uint256[] memory) {
        return investorProjects[_investor];
    }


    function getInvestorContribution(uint256 _projectId, address _investor) external view returns (uint256) {
        return investorContributions[_projectId][_investor];
    }


    function setPlatformFeePercentage(uint256 _newFeePercentage) external onlyPlatformOwner {
        require(_newFeePercentage <= 1000, "Platform fee cannot exceed 10%");

        uint256 oldFeePercentage = platformFeePercentage;
        platformFeePercentage = _newFeePercentage;

        emit PlatformFeeChanged(oldFeePercentage, _newFeePercentage);
    }


    function transferPlatformOwnership(address payable _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != platformOwner, "New owner must be different from current owner");

        platformOwner = _newOwner;
    }


    function getPlatformStats() external view returns (
        uint256 totalProjects,
        uint256 totalRaised,
        uint256 totalFees
    ) {
        return (totalProjectsCreated, totalAmountRaised, collectedFees);
    }


    bool public emergencyPaused = false;

    modifier whenNotPaused() {
        require(!emergencyPaused, "Contract is paused");
        _;
    }

    function setEmergencyPause(bool _paused) external onlyPlatformOwner {
        emergencyPaused = _paused;
    }


    function createProjectWhenNotPaused(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external whenNotPaused {


        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than zero");
        require(_durationInDays > 0 && _durationInDays <= 365, "Duration must be between 1 and 365 days");

        uint256 projectId = nextProjectId;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        projects[projectId] = Project({
            projectId: projectId,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            exists: true
        });

        creatorProjects[msg.sender].push(projectId);

        nextProjectId++;
        totalProjectsCreated++;

        emit ProjectCreated(projectId, msg.sender, _title, _goalAmount, deadline);
    }
}
