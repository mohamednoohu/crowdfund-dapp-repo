// SPDX-License-Identifier: GPL-3.0

// @author Mohamed Noohu

pragma solidity >=0.7.0 <0.9.0;

contract CrowdFund {

    // Project statuses
    enum ProjectStatus {WFA, RJC, APR, PGA, XRQ, XRR, XRA, XRJ, RFD, CLD}

    // Structure of the project
    struct Project {
       // uint projectId; 
        uint minimumAmount;
        uint goal;  
        uint raisedAmount; 
        address owner;  
        address charityAddress;
        bool acceptDonation; 
        string documentLink;
        ProjectStatus projectStatus; 
    }

    // Structure of the charity
    struct Charity {
       // uint charityId;
        bool approved;
        string reason;
        string licenseDocsLink;
        address owner;  
    }

    // Structure of the donor
    struct Donor {
        uint donorId;
        address owner; 
        mapping(address => uint) projectwiseContributions;
    }

    // To hold created projects
    mapping(address => Project) projects;

    //To hold created charities
    mapping(address => Charity) charities;

    // Address of the board admin
    address public boardAdmin;
    
    // Projects created under this charity
    mapping (address => Project[]) charityProjects; 

    // Contains all donor details for a project
    mapping(address => Donor[]) projectDonors;

    // Reciever/project will emit this event that will be received by the charity 
    event ReceiverMessageToCharity(address charityAddress, address projectAddress, ProjectStatus projectStatus);

    // Board will emit this event that will be received by the charity
    event BoardMessageToCharity(address charityAddress, address projectAddress, ProjectStatus projectStatus);

    // Charity will emit this event that will be received by the board
    event CharityMessageToBoard(address charityAddress, address projectAddress, ProjectStatus projectStatus);

    // Charity will emit this event that will be received by the Receiver/project
    event CharityMessageToReceiver(address charityAddress, address projectAddress, ProjectStatus projectStatus);

    // Charity will emit this event that will be received by the donor
    event CharityMessageToDonor(address charityAddress, address projectAddress, ProjectStatus projectStatus);

    
    // Text equivalent to status enums
    string constant WFA = "Waiting for approval";
    string constant APR = "Approved";
    string constant RJC = "Rejected by charity";
    string constant PGA = "Project goal achieved";
    string constant XRQ = "Exchange requested";
    string constant XRR = "Exchange request received";
    string constant XRA = "Exchange request approved";
    string constant XRJ = "Exchange request rejected";
    string constant RFD = "Funds refunded";
    string constant CLD = "Project closed";
    string constant NO_AUTH = "You are not authorized to update with this status";
    string constant ONLY_ADMIN = "This operation can be performed only by Board admin";
    string constant ONLY_CHARITY = "This operation can be performed only by Charity";

    ProjectStatus public projectStatus;

    // Contains project status
    mapping(ProjectStatus => string) public projectStatuses;

    modifier onlyBoardAdmin(){
        require(msg.sender==boardAdmin,ONLY_ADMIN);
        _;
    }
    
    modifier onlyCharity(){
        require(msg.sender!=boardAdmin,ONLY_CHARITY);
        _;
    }

    constructor () {
        boardAdmin = msg.sender;

        projectStatuses[ProjectStatus.WFA] = WFA;
        projectStatuses[ProjectStatus.APR] = APR;
        projectStatuses[ProjectStatus.RJC] = RJC;
        projectStatuses[ProjectStatus.PGA] = PGA;
        projectStatuses[ProjectStatus.XRQ] = XRQ;
        projectStatuses[ProjectStatus.XRR] = XRR;
        projectStatuses[ProjectStatus.XRA] = XRA;
        projectStatuses[ProjectStatus.XRJ] = XRJ;
        projectStatuses[ProjectStatus.RFD] = RFD;
        projectStatuses[ProjectStatus.CLD] = CLD;
    }

    // Only board can create the charity with waiting status
    function createCharity(string memory _licenseDocsLink, address owner) public onlyBoardAdmin {
        
        Charity memory charity = Charity({
           approved: false,
           reason: "",
           licenseDocsLink: _licenseDocsLink,
           owner: owner
        });
 
        charities[owner] = charity;   
    }

    // Only board can update the charity status
    function updateCharityStatus(address charityAddress, bool status, string memory reason) public onlyBoardAdmin {
        require(charities[charityAddress].owner == charityAddress,"Charity doesn't exist");
        charities[charityAddress].approved = status;
        charities[charityAddress].reason = reason;
    }

    // Charity will create the project once it got approved by the board
    // Initially the project will be created in waiting for approval status
    function createProject(uint _minimumAmount, uint _goal, address owner, string memory _documentLink) onlyCharity public {
        require(charities[msg.sender].owner == msg.sender,"Charity doesn't exist");
        require(charities[msg.sender].approved,"This charity is not yet approved");
    
        Project memory project = Project({
           minimumAmount: _minimumAmount,
           goal: _goal,
           raisedAmount: 0,
           owner: owner,
           charityAddress: msg.sender,
           acceptDonation: false,
           documentLink: _documentLink,
           projectStatus: ProjectStatus.WFA
        });

        projects[owner] = project; 
        
        charityProjects[msg.sender].push(project);
    }
   
   // Only board can call this function to update the charity status
    function updateProjectStatusByAdmin(address charityAddress, address projectAddress, uint8 enumValue) onlyBoardAdmin public {
        
        // The status may be XRR or XRA or XRJ

        require(ProjectStatus(enumValue) != ProjectStatus.WFA,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.APR,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.PGA,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.XRQ,NO_AUTH);

        Project[] storage projectList = charityProjects[charityAddress];
        require(projectList.length > 0,"No project exist under this charity");
       
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].owner == projectAddress) {
                projectList[i].projectStatus = ProjectStatus(enumValue);

                // Notify the project status to the charity. 
                // Charity will delegate the appropriate event to the project/receiver
                emit BoardMessageToCharity(charityAddress, projectAddress, projectList[i].projectStatus);

                break;
            }
        }
        
    }
   // Only charity can call this function to update the charity status
    function updateProjectStatusByCharity(address projectAddress, uint8 enumValue) onlyCharity public {

        bool exist = false;

        require(ProjectStatus(enumValue) != ProjectStatus.PGA,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.XRR,NO_AUTH);

        Project[] storage projectList = charityProjects[msg.sender];
        require(projectList.length > 0,"No project exist under this charity");

        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].owner == projectAddress) {
                
                exist = true;

                if (ProjectStatus(enumValue) == ProjectStatus.XRJ ||
                    ProjectStatus(enumValue) == ProjectStatus.XRA) {

                    projectList[i].acceptDonation = false;

                    // Notify the project status to the receiver/project 
                    emit CharityMessageToReceiver(msg.sender, projectAddress, ProjectStatus(enumValue));

                    // If rejected by the board
                    if (ProjectStatus(enumValue) == ProjectStatus.XRJ) {
                        
                        // refund to all donors
                        refundToAllDonors(msg.sender, projectAddress);
                        
                        // Notify donors as funds refunded 
                        emit CharityMessageToDonor(msg.sender, projectAddress, ProjectStatus.RFD);

                    } else if (ProjectStatus(enumValue) == ProjectStatus.XRA) {
                        //transfer raised amount to the receiver/project
                        transferToReceiver(msg.sender, projectAddress);

                        // Notify donors as project closed 
                        emit CharityMessageToDonor(msg.sender, projectAddress, ProjectStatus.CLD);
                    }
                } else {

                    // Update the project status
                    projectList[i].projectStatus = ProjectStatus(enumValue);

                    if (ProjectStatus(enumValue) == ProjectStatus.APR) {
                         projectList[i].acceptDonation = true;
                    } else if (ProjectStatus(enumValue) == ProjectStatus.XRQ) {

                         projectList[i].acceptDonation = false;

                        // Notify the project status to the Board 
                        emit CharityMessageToBoard(msg.sender, projectAddress, ProjectStatus.XRQ);
                    }
                }
            }

            if (exist)
                break;
        }
    }

    // Return the fund details of the project
    function getProjectFundDetails(address charityAddress, address projectAddress) public view returns (
        uint, uint, uint) {
            //require(projects.length > 0,"No project is created yet");

            Project[] storage projectList = charityProjects[charityAddress];
            require(projectList.length > 0,"No project exist under this charity");

            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].owner == projectAddress) {
                    return (
                        projectList[i].goal,
                        projectList[i].raisedAmount,
                        projectList[i].goal - projectList[i].raisedAmount
                    );
                }
            }

             revert("No such project exist under this charity");
    }

    // Return the balance in the wallet of the project owner
    function getProjectOwnerBalance(address charityAddress, address projectAddress) public view returns (
        uint) {
        Project[] storage projectList = charityProjects[charityAddress];
        require(projectList.length > 0,"No project exist under this charity");
        uint balance = 0;
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].owner == projectAddress) {
                balance = projectList[i].owner.balance;
                break;
            }
        }

        return balance;
    }

    // Return the balance in the wallet of the donor
    function getDonorBalance(address charityAddress, address projectAddress, address donorAddress) public view returns (
        uint) {
            Project[] storage projectList = charityProjects[charityAddress];
            require(projectList.length > 0,"No project exist under this charity");

            uint balance = 0;
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].owner == projectAddress) {
                     Donor[] storage allDonors = projectDonors[projectAddress];
                     for (uint j=0;j<allDonors.length;j++) {
                         if (allDonors[j].owner == donorAddress) {
                            balance = allDonors[j].owner.balance;
                            break;
                        }
                     }
                }
            }

            return balance;
    }

    // Return all projects under the given charity
    function getProjectListByCharity(address charityAddress) public view returns (
       address[] memory _projectAddresses, uint[] memory _minimumAmounts, uint[] memory _goals, uint[] memory _raisedAmounts) {
            Project[] storage projectList = charityProjects[charityAddress];
            require(projectList.length > 0,"No project exist under this charity");

            address[] memory projectAddresses = new address[] (projectList.length);
            uint[] memory minimumAmounts = new uint[] (projectList.length);
            uint[] memory goals = new uint[] (projectList.length);
            uint[] memory raisedAmounts = new uint[] (projectList.length);

            uint j = 0;
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].acceptDonation) {
                    projectAddresses[j] = projectList[i].owner;
                    minimumAmounts[j] = projectList[i].minimumAmount;
                    goals[j] = projectList[i].goal;
                    raisedAmounts[j] = projectList[i].raisedAmount;
                    j++;
                }
            }
            
            require(projectAddresses.length > 0,"No projects available for accepting donations");

            return (projectAddresses, minimumAmounts, goals, raisedAmounts);

    }

    // Donors will call this function to donate for the selected project of the charity
    function donate(address charityAddress, address projectAddress) public payable {
            bool projectExist = false;
            Project[] storage projectList = charityProjects[charityAddress];

            require(projectList.length > 0,"No project exist under this charity");
            require(msg.value <= msg.sender.balance, "You dont't have sufficient funds to donate");

            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].owner == projectAddress) { 
                    if (projectList[i].acceptDonation) {
                        
                        require(msg.value >= projectList[i].minimumAmount, "Should be greater than or equal to minimum amount");
                        
                        require(msg.value + projectList[i].raisedAmount <= projectList[i].goal, "Your contribution exceeds required amount.");

                        projectList[i].raisedAmount = projectList[i].raisedAmount + msg.value;

                        Donor[] storage allDonors = projectDonors[projectAddress];
                        uint idx = allDonors.length;
                        bool donorExist;

                        for (uint j=0;j<allDonors.length;j++) {
                            // If the donor and message sender are same, the amount should be added with  
                            // existing amount under the specific project
                             if (allDonors[j].owner == msg.sender) {
                                allDonors[j].projectwiseContributions[projectAddress] += msg.value;
                                donorExist = true;
                               
                                break;
                            }
                        }

                        if (!donorExist) {   
                            // It means no donor already exist for this project
                
                            // let's create a new donor

                            allDonors.push();

                            Donor storage newDonor = allDonors[idx];
                            newDonor.owner = msg.sender;
                            newDonor.projectwiseContributions[projectAddress] = msg.value;
                        }

                        // If the project goal is reached
                        if (projectList[i].raisedAmount == projectList[i].goal) {
                            
                            // Change the status
                            projectList[i].projectStatus = ProjectStatus.PGA;

                            // No more donations accepted
                            projectList[i].acceptDonation = false;

                            // Notify the project status to the receiver. 
                            emit ReceiverMessageToCharity(charityAddress, projectAddress, ProjectStatus.PGA);
                        }
                    } else {
                        revert("No more donations accepted for this project.");
                    }

                    projectExist = true;
                    break;
                }
            }

            if (!projectExist)
                revert("No such project exist under this charity");
    }

    // Donor will call this function to get refund
    function getRefund(address charityAddress, address projectAddress) public {
        bool projectExist = false;
        bool donorExist = false;
        
        Project[] storage projectList = charityProjects[charityAddress];
        require(projectList.length > 0,"No project exist under this charity");

        Donor[] storage allDonors = projectDonors[projectAddress];

        for (uint j=0;j<allDonors.length;j++) {
            // If the donor and message sender are same and has given some contribution to this project
            if (allDonors[j].owner == msg.sender && allDonors[j].projectwiseContributions[projectAddress] > 0) {
                for (uint i=0;i<projectList.length;i++) {
                    if (projectList[i].owner == projectAddress) { 
                        if (projectList[i].projectStatus > ProjectStatus.PGA) {
                            revert("Can't refund as exchange request was already initiated with board");
                        } else {
                            projectList[i].raisedAmount = projectList[i].raisedAmount - allDonors[j].projectwiseContributions[projectAddress];
                            
                            // Add the amount to donor's wallet 
                            payable (allDonors[j].owner).transfer(allDonors[j].projectwiseContributions[projectAddress]);

                            // If accepting donation was stopped
                            if (!projectList[i].acceptDonation) {

                                // Make it acceptable again
                                projectList[i].acceptDonation = true;
                            }
                        }

                        projectExist = true;
                        break;
                    } 
                }
                
                if (!projectExist) {
                    revert("No project exist under this projectId");
                }                           

                payable (msg.sender).transfer(allDonors[j].projectwiseContributions[projectAddress]);
                allDonors[j].projectwiseContributions[projectAddress] = 0;

                donorExist = true;
                break;
            }
        }

        if (!donorExist)
            revert("You haven't contributed for this project");
    }

    // Called within the smart contract to refund the donated amounts to the donors
    // when the exchange requiest is rejected by the board
    function refundToAllDonors(address charityAddress, address projectAddress) private {
        bool projectExist = false;
        Project[] storage projectList = charityProjects[charityAddress];
        require(projectList.length > 0,"No project exist under this charity");
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].owner == projectAddress) { 
                require(projectList[i].projectStatus == ProjectStatus.XRJ, "Can't refund as exchange request was not rejected by the board");
            
                Donor[] storage allDonors = projectDonors[projectAddress];

                for (uint j=0;j<allDonors.length;j++) {
                    uint contribution = allDonors[j].projectwiseContributions[projectAddress];
                    payable (allDonors[j].owner).transfer(contribution);
                }
                
                projectExist = true;
                break;
            }
        }

        if (!projectExist)
            revert("No project exist under this projectId");
    }

    // Called within the smart contract to transfer the raised amounts to the project/receiver
    // when the exchange requiest is approved by the board
    function transferToReceiver(address charityAddress, address projectAddress) private {
        bool projectExist = false;
        Project[] storage projectList = charityProjects[charityAddress];
        require(projectList.length > 0,"No project exist under this charity");
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].owner == projectAddress) { 
                payable (projectList[i].owner).transfer(projectList[i].raisedAmount);
                projectExist = true;
                break;
            }
        }

        if (!projectExist)
            revert("No project exist under this projectId");
    }

    // Return project status
    function getProjectStatus(address charityAddress, address projectAddress) external view returns (
        string memory) {
        Project[] storage projectList = charityProjects[charityAddress];
        require(projectList.length > 0,"No project exist under this charity");
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].owner == projectAddress) {
                return projectStatuses[projectList[i].projectStatus];
            } 
        }

        revert("No such project exist under this charity");
    }
}