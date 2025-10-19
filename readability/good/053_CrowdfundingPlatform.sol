
pragma solidity ^0.8.0;


contract CrowdfundingPlatform {


    enum ProjectStatus {
        Active,
        Successful,
        Failed,
        Cancelled
    }


    struct Project {
        uint256 projectId;
        address payable creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        ProjectStatus status;
        bool fundsWithdrawn;
    }


    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
    }


    uint256 private nextProjectId;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => Investment[]) public projectInvestments;
    mapping(uint256 => mapping(address => uint256)) public userInvestments;
    mapping(address => uint256[]) public userProjects;

    address public platformOwner;
    uint256 public platformFeePercentage;
    uint256 public minimumInvestment;


    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        string title,
        uint256 targetAmount,
        uint256 deadline
    );

    event InvestmentMade(
        uint256 indexed projectId,
        address indexed investor,
        uint256 amount,
        uint256 timestamp
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


    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(msg.sender == projects[_projectId].creator, "Only project creator can call this function");
        _;
    }

    modifier projectExists(uint256 _projectId) {
        require(_projectId < nextProjectId, "Project does not exist");
        _;
    }

    modifier validInvestmentAmount() {
        require(msg.value >= minimumInvestment, "Investment amount below minimum");
        _;
    }


    constructor(uint256 _platformFeePercentage, uint256 _minimumInvestment) {
        require(_platformFeePercentage <= 1000, "Platform fee cannot exceed 10%");

        platformOwner = msg.sender;
        platformFeePercentage = _platformFeePercentage;
        minimumInvestment = _minimumInvestment;
        nextProjectId = 0;
    }


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Project title cannot be empty");
        require(bytes(_description).length > 0, "Project description cannot be empty");
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 365, "Duration must be between 1 and 365 days");

        uint256 projectId = nextProjectId;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        projects[projectId] = Project({
            projectId: projectId,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            raisedAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            fundsWithdrawn: false
        });

        userProjects[msg.sender].push(projectId);
        nextProjectId++;

        emit ProjectCreated(projectId, msg.sender, _title, _targetAmount, deadline);

        return projectId;
    }


    function investInProject(uint256 _projectId)
        external
        payable
        projectExists(_projectId)
        validInvestmentAmount
    {
        Project storage project = projects[_projectId];

        require(project.status == ProjectStatus.Active, "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.sender != project.creator, "Project creator cannot invest in own project");


        project.raisedAmount += msg.value;


        userInvestments[_projectId][msg.sender] += msg.value;


        projectInvestments[_projectId].push(Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        if (project.raisedAmount >= project.targetAmount) {
            ProjectStatus oldStatus = project.status;
            project.status = ProjectStatus.Successful;
            emit ProjectStatusChanged(_projectId, oldStatus, ProjectStatus.Successful);
        }

        emit InvestmentMade(_projectId, msg.sender, msg.value, block.timestamp);
    }


    function withdrawFunds(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
    {
        Project storage project = projects[_projectId];

        require(project.status == ProjectStatus.Successful, "Project must be successful to withdraw funds");
        require(!project.fundsWithdrawn, "Funds already withdrawn");
        require(project.raisedAmount > 0, "No funds to withdraw");

        project.fundsWithdrawn = true;


        uint256 platformFee = (project.raisedAmount * platformFeePercentage) / 10000;
        uint256 creatorAmount = project.raisedAmount - platformFee;


        project.creator.transfer(creatorAmount);


        if (platformFee > 0) {
            payable(platformOwner).transfer(platformFee);
        }

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
    }


    function requestRefund(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];


        if (project.status == ProjectStatus.Active && block.timestamp >= project.deadline) {
            ProjectStatus oldStatus = project.status;
            project.status = ProjectStatus.Failed;
            emit ProjectStatusChanged(_projectId, oldStatus, ProjectStatus.Failed);
        }

        require(project.status == ProjectStatus.Failed, "Refunds only available for failed projects");

        uint256 investmentAmount = userInvestments[_projectId][msg.sender];
        require(investmentAmount > 0, "No investment found for this user");


        userInvestments[_projectId][msg.sender] = 0;


        payable(msg.sender).transfer(investmentAmount);

        emit RefundIssued(_projectId, msg.sender, investmentAmount);
    }


    function cancelProject(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
    {
        Project storage project = projects[_projectId];

        require(project.status == ProjectStatus.Active, "Can only cancel active projects");
        require(project.raisedAmount == 0, "Cannot cancel project with existing investments");

        ProjectStatus oldStatus = project.status;
        project.status = ProjectStatus.Cancelled;

        emit ProjectStatusChanged(_projectId, oldStatus, ProjectStatus.Cancelled);
    }


    function getProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Project memory)
    {
        return projects[_projectId];
    }


    function getProjectInvestmentCount(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (uint256)
    {
        return projectInvestments[_projectId].length;
    }


    function getUserInvestment(uint256 _projectId, address _investor)
        external
        view
        projectExists(_projectId)
        returns (uint256)
    {
        return userInvestments[_projectId][_investor];
    }


    function getUserProjects(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userProjects[_user];
    }


    function getTotalProjectCount()
        external
        view
        returns (uint256)
    {
        return nextProjectId;
    }


    function updatePlatformFee(uint256 _newFeePercentage)
        external
        onlyPlatformOwner
    {
        require(_newFeePercentage <= 1000, "Platform fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }


    function updateMinimumInvestment(uint256 _newMinimumInvestment)
        external
        onlyPlatformOwner
    {
        minimumInvestment = _newMinimumInvestment;
    }


    function transferPlatformOwnership(address _newOwner)
        external
        onlyPlatformOwner
    {
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }
}
