
pragma solidity ^0.8.0;


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
        uint256 targetAmount;
        uint256 currentAmount;
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
    mapping(uint256 => mapping(address => uint256)) public investorContributions;
    mapping(address => uint256[]) public creatorProjects;
    mapping(address => uint256[]) public investorProjects;

    address public platformOwner;
    uint256 public platformFeePercentage;


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
        uint256 newTotalAmount
    );

    event ProjectStatusUpdated(
        uint256 indexed projectId,
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

    modifier projectActive(uint256 _projectId) {
        require(projects[_projectId].status == ProjectStatus.Active, "Project is not active");
        _;
    }


    constructor(uint256 _platformFeePercentage) {
        require(_platformFeePercentage <= 1000, "Platform fee cannot exceed 10%");
        platformOwner = msg.sender;
        platformFeePercentage = _platformFeePercentage;
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
            currentAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            fundsWithdrawn: false
        });

        creatorProjects[msg.sender].push(projectId);
        nextProjectId++;

        emit ProjectCreated(projectId, msg.sender, _title, _targetAmount, deadline);

        return projectId;
    }


    function investInProject(uint256 _projectId)
        external
        payable
        projectExists(_projectId)
        projectActive(_projectId)
    {
        require(msg.value > 0, "Investment amount must be greater than 0");
        require(block.timestamp < projects[_projectId].deadline, "Project deadline has passed");
        require(msg.sender != projects[_projectId].creator, "Project creator cannot invest in their own project");

        Project storage project = projects[_projectId];


        if (investorContributions[_projectId][msg.sender] == 0) {
            investorProjects[msg.sender].push(_projectId);
        }

        investorContributions[_projectId][msg.sender] += msg.value;
        project.currentAmount += msg.value;

        projectInvestments[_projectId].push(Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        if (project.currentAmount >= project.targetAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectStatusUpdated(_projectId, ProjectStatus.Successful);
        }

        emit InvestmentMade(_projectId, msg.sender, msg.value, project.currentAmount);
    }


    function withdrawFunds(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
    {
        Project storage project = projects[_projectId];

        require(project.status == ProjectStatus.Successful, "Project must be successful to withdraw funds");
        require(!project.fundsWithdrawn, "Funds have already been withdrawn");
        require(project.currentAmount > 0, "No funds to withdraw");

        uint256 totalAmount = project.currentAmount;
        uint256 platformFee = (totalAmount * platformFeePercentage) / 10000;
        uint256 creatorAmount = totalAmount - platformFee;

        project.fundsWithdrawn = true;
        project.status = ProjectStatus.Withdrawn;


        project.creator.transfer(creatorAmount);


        if (platformFee > 0) {
            payable(platformOwner).transfer(platformFee);
        }

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
        emit ProjectStatusUpdated(_projectId, ProjectStatus.Withdrawn);
    }


    function requestRefund(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];


        if (block.timestamp >= project.deadline && project.currentAmount < project.targetAmount && project.status == ProjectStatus.Active) {
            project.status = ProjectStatus.Failed;
            emit ProjectStatusUpdated(_projectId, ProjectStatus.Failed);
        }

        require(project.status == ProjectStatus.Failed, "Refunds only available for failed projects");

        uint256 investmentAmount = investorContributions[_projectId][msg.sender];
        require(investmentAmount > 0, "No investment found for this investor");


        investorContributions[_projectId][msg.sender] = 0;
        project.currentAmount -= investmentAmount;


        payable(msg.sender).transfer(investmentAmount);

        emit RefundIssued(_projectId, msg.sender, investmentAmount);
    }


    function updatePlatformFee(uint256 _newFeePercentage)
        external
        onlyPlatformOwner
    {
        require(_newFeePercentage <= 1000, "Platform fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }


    function getProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Project memory)
    {
        return projects[_projectId];
    }


    function getProjectInvestments(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Investment[] memory)
    {
        return projectInvestments[_projectId];
    }


    function getCreatorProjects(address _creator)
        external
        view
        returns (uint256[] memory)
    {
        return creatorProjects[_creator];
    }


    function getInvestorProjects(address _investor)
        external
        view
        returns (uint256[] memory)
    {
        return investorProjects[_investor];
    }


    function getInvestorContribution(uint256 _projectId, address _investor)
        external
        view
        returns (uint256)
    {
        return investorContributions[_projectId][_investor];
    }


    function getTotalProjectCount()
        external
        view
        returns (uint256)
    {
        return nextProjectId;
    }


    function canRequestRefund(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (bool)
    {
        Project memory project = projects[_projectId];
        return (project.status == ProjectStatus.Failed) ||
               (block.timestamp >= project.deadline && project.currentAmount < project.targetAmount);
    }


    function emergencyWithdraw()
        external
        onlyPlatformOwner
    {
        payable(platformOwner).transfer(address(this).balance);
    }


    function getContractBalance()
        external
        view
        returns (uint256)
    {
        return address(this).balance;
    }
}
