
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


    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant BASIS_POINTS = 10000;


    address payable public platformOwner;


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

    event ProjectStatusChanged(
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


    modifier onlyProjectCreator(uint256 _projectId) {
        require(
            projects[_projectId].creator == msg.sender,
            "Only project creator can perform this action"
        );
        _;
    }

    modifier projectExists(uint256 _projectId) {
        require(
            _projectId < nextProjectId && _projectId > 0,
            "Project does not exist"
        );
        _;
    }

    modifier onlyPlatformOwner() {
        require(
            msg.sender == platformOwner,
            "Only platform owner can perform this action"
        );
        _;
    }


    constructor() {
        platformOwner = payable(msg.sender);
        nextProjectId = 1;
    }


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) external returns (uint256 projectId) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(_durationInDays <= 365, "Duration cannot exceed 365 days");

        projectId = nextProjectId;
        nextProjectId++;

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

        emit ProjectCreated(projectId, msg.sender, _title, _targetAmount, deadline);
    }


    function investInProject(uint256 _projectId)
        external
        payable
        projectExists(_projectId)
    {
        require(msg.value > 0, "Investment amount must be greater than 0");

        Project storage project = projects[_projectId];
        require(project.status == ProjectStatus.Active, "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.sender != project.creator, "Creator cannot invest in own project");


        project.currentAmount += msg.value;
        investorContributions[_projectId][msg.sender] += msg.value;

        projectInvestments[_projectId].push(Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        if (investorContributions[_projectId][msg.sender] == msg.value) {
            investorProjects[msg.sender].push(_projectId);
        }

        emit InvestmentMade(_projectId, msg.sender, msg.value, project.currentAmount);


        if (project.currentAmount >= project.targetAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectStatusChanged(_projectId, ProjectStatus.Successful);
        }
    }


    function withdrawFunds(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
    {
        Project storage project = projects[_projectId];
        require(project.status == ProjectStatus.Successful, "Project must be successful");
        require(!project.fundsWithdrawn, "Funds already withdrawn");
        require(project.currentAmount > 0, "No funds to withdraw");

        project.fundsWithdrawn = true;
        project.status = ProjectStatus.Withdrawn;

        uint256 totalAmount = project.currentAmount;
        uint256 platformFee = (totalAmount * PLATFORM_FEE_RATE) / BASIS_POINTS;
        uint256 creatorAmount = totalAmount - platformFee;


        project.creator.transfer(creatorAmount);


        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
        emit ProjectStatusChanged(_projectId, ProjectStatus.Withdrawn);
    }


    function requestRefund(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];


        if (project.status == ProjectStatus.Active && block.timestamp >= project.deadline) {
            project.status = ProjectStatus.Failed;
            emit ProjectStatusChanged(_projectId, ProjectStatus.Failed);
        }

        require(project.status == ProjectStatus.Failed, "Refund only available for failed projects");
        require(!project.fundsWithdrawn, "Funds already withdrawn");

        uint256 investmentAmount = investorContributions[_projectId][msg.sender];
        require(investmentAmount > 0, "No investment found for this investor");


        investorContributions[_projectId][msg.sender] = 0;
        project.currentAmount -= investmentAmount;


        payable(msg.sender).transfer(investmentAmount);

        emit RefundIssued(_projectId, msg.sender, investmentAmount);
    }


    function getProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Project memory project)
    {
        return projects[_projectId];
    }


    function getProjectInvestments(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Investment[] memory investments)
    {
        return projectInvestments[_projectId];
    }


    function getInvestorContribution(uint256 _projectId, address _investor)
        external
        view
        returns (uint256 amount)
    {
        return investorContributions[_projectId][_investor];
    }


    function getCreatorProjects(address _creator)
        external
        view
        returns (uint256[] memory projectIds)
    {
        return creatorProjects[_creator];
    }


    function getInvestorProjects(address _investor)
        external
        view
        returns (uint256[] memory projectIds)
    {
        return investorProjects[_investor];
    }


    function getTotalProjectsCount() external view returns (uint256 count) {
        return nextProjectId - 1;
    }


    function updatePlatformOwner(address payable _newOwner)
        external
        onlyPlatformOwner
    {
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }


    function emergencyWithdraw() external onlyPlatformOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        platformOwner.transfer(balance);
    }


    function getContractBalance() external view returns (uint256 balance) {
        return address(this).balance;
    }
}
