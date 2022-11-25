// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract CrowdFund {

    enum ProjectStatus {WFA, RJC, APR, PGA, XRQ, XRR, XRA, XRJ, RFD, CLD}

    struct Project {
        uint projectId; 
        uint minimumAmount;
        uint goal;  
        uint raisedAmount; 
        address owner;  
        bool acceptDonation; 
        string documentLink;
        ProjectStatus projectStatus; 
    }

    struct Charity {
        uint charityId;
        bool approved;
        string reason;
        string licenseDocsLink;
        address owner;  
    }

    struct Donor {
        uint donorId;
        address owner; 
        mapping(uint => uint) projectwiseContributions;
    }

    Project[] public projects;
    Charity[] public charities;
    address public boardAdmin;
    
    mapping (uint => Project[]) charityProjects; // Projects created under this charity

    mapping(uint => bool) approvedCharities; // Charities approved by the board

    //mapping(uint => ProjectDonor) projectDonors;

    mapping(uint => Donor[]) projectDonors;

    // Reciever/project will emit this event that will be received by the charity 
    event ReceiverMessageToCharity(uint charityId, uint projectId, ProjectStatus projectStatus);

    // Board will emit this event that will be received by the charity
    event BoardMessageToCharity(uint charityId, uint projectId, ProjectStatus projectStatus);

    // Charity will emit this event that will be received by the board
    event CharityMessageToBoard(uint charityId, uint projectId, ProjectStatus projectStatus);

    // Charity will emit this event that will be received by the Receiver/project
    event CharityMessageToReceiver(uint charityId, uint projectId, ProjectStatus projectStatus);

    // Charity will emit this event that will be received by the donor
    event CharityMessageToDonor(uint charityId, uint projectId, ProjectStatus projectStatus);

    

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

    function createCharity(uint _charityId, string memory _licenseDocsLink, address charity) public onlyBoardAdmin {
        
        Charity memory newCharity = Charity({
           charityId: _charityId,
           approved: false,
           reason: "",
           licenseDocsLink: _licenseDocsLink,
           owner: charity
        });

        charities.push(newCharity); 
        
    }

    function updateCharityStatus(uint charityId, bool status, string memory reason) public onlyBoardAdmin {
        require(charities.length > 0,"No charity is registered yet");
        bool found = false;
        for (uint i=0;i<charities.length;i++) {
            if (charities[i].charityId == charityId) {
                charities[i].approved = status;
                
                if (status == true)
                    approvedCharities[charityId] = true;
                else
                    charities[i].reason = reason;
                    
                found = true;
                
                break;
            }
        }

        if (!found)
            revert("No charity exist under this charity id");

    }


    // Charity will create the project once it got approved by the board
    function createProject(uint charityId, uint _projectId, uint _minimumAmount, uint _goal, address owner, string memory _documentLink) onlyCharity public {
        require(charities.length > 0,"No charity is registered yet");
        require(approvedCharities[charityId],"This charity is not yet approved");
    
        Project memory newProject = Project({
           projectId: _projectId,
           minimumAmount: _minimumAmount,
           goal: _goal,
           raisedAmount: 0,
           owner: owner,
           acceptDonation: true,
           documentLink: _documentLink,
           projectStatus: ProjectStatus.APR
        });

        projects.push(newProject);
        
        charityProjects[charityId].push(newProject);
    }
   
    function updateProjectStatusByAdmin(uint projectId, uint charityId, uint8 enumValue) onlyBoardAdmin public {
        
        require(projects.length > 0,"No project is created yet");

        // The status may be XRR or XRA or XRJ

        require(ProjectStatus(enumValue) != ProjectStatus.WFA,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.APR,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.PGA,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.XRQ,NO_AUTH);

        Project[] storage projectList = charityProjects[charityId];
        require(projectList.length > 0,"No project exist under this charity");
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].projectId == projectId) {
                projectList[i].projectStatus = ProjectStatus(enumValue);

                // Notify the project status to the charity. 
                // Charity will delegate the appropriate event to the project/receiver
                emit BoardMessageToCharity(charityId, projectId, projectList[i].projectStatus);

                break;
            }
        }
    }
   // Charity can change its project status only
    function updateProjectStatusByCharity(uint projectId, uint charityId, uint8 enumValue) onlyCharity public {

        bool exist = false;

        require(ProjectStatus(enumValue) != ProjectStatus.PGA,NO_AUTH);
        require(ProjectStatus(enumValue) != ProjectStatus.XRR,NO_AUTH);
       // require(ProjectStatus(enumValue) != ProjectStatus.XRA,NO_AUTH);
       // require(ProjectStatus(enumValue) != ProjectStatus.XRJ,NO_AUTH);

        Project[] storage projectList = charityProjects[charityId];
        require(projectList.length > 0,"No project exist under this project id");

        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].projectId == projectId) {
                
                exist = true;

                projectList[i].acceptDonation = false;

                if (ProjectStatus(enumValue) == ProjectStatus.XRJ ||
                    ProjectStatus(enumValue) == ProjectStatus.XRA) {

                    // Notify the project status to the receiver/project 
                    emit CharityMessageToReceiver(charityId, projectId, ProjectStatus(enumValue));

                    // If rejected by the board
                    if (ProjectStatus(enumValue) == ProjectStatus.XRJ) {
                        
                        // refund to all donors
                        refundToAllDonors(charityId, projectId);
                        
                        // Notify donors as funds refunded 
                        emit CharityMessageToDonor(charityId, projectId, ProjectStatus.RFD);

                    } else if (ProjectStatus(enumValue) == ProjectStatus.XRA) {
                        //transfer raised amount to the receiver/project
                        tranferToReceiver(charityId, projectId);

                        // Notify donors as project closed 
                        emit CharityMessageToDonor(charityId, projectId, ProjectStatus.CLD);
                    }
                } else {

                    // Update the project status
                    projectList[i].projectStatus = ProjectStatus(enumValue);

                    if (ProjectStatus(enumValue) == ProjectStatus.XRQ) {
                        // Notify the project status to the Board 
                        emit CharityMessageToBoard(charityId, projectId, ProjectStatus.XRQ);
                    }
                }
            }

            if (exist)
                break;
        }
    }

    // Return the fund details of the project
    function getProjectFundDetails(uint charityId, uint projectId) public view returns (
        uint, uint, uint) {
            require(projects.length > 0,"No project is created yet");

            Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId) {
                    return (
                        projectList[i].goal,
                        projectList[i].raisedAmount,
                        projectList[i].goal - projectList[i].raisedAmount
                    );
                }
            }

             revert("No such project exist under this charity");
    }

    // Return the fund details of the project
    function getProjectOwnerBalance(uint charityId, uint projectId) public view returns (
        uint) {
            require(projects.length > 0,"No project is created yet");

            Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId) {
                    return projectList[i].owner.balance;
                }
            }

             revert("No such project exist under this charity");
    }

    // Return the fund details of the project
    function getDonorBalance(uint charityId, uint projectId, uint donorId) public view returns (
        uint) {
            require(projects.length > 0,"No project is created yet");

            Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId) {
                     Donor[] storage allDonors = projectDonors[projectId];
                     for (uint j=0;j<allDonors.length;j++) {
                         if (allDonors[j].donorId == donorId) {
                            return allDonors[j].owner.balance;
                        }
                     }
                    
                }
            }

             revert("No such donor exist under this project under this charity");
    }

    // Return all projects under the given charity
    function getProjectListByCharity(uint charityId) public view returns (
       uint[] memory _projectIds, uint[] memory _minimumAmounts, uint[] memory _goals, uint[] memory _raisedAmounts) {
            require(projects.length > 0,"No project is created yet");

            Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"No projects found under this charity");

            uint[] memory projectIds = new uint[] (projectList.length);
            uint[] memory minimumAmounts = new uint[] (projectList.length);
            uint[] memory goals = new uint[] (projectList.length);
            uint[] memory raisedAmounts = new uint[] (projectList.length);

            uint j = 0;
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].acceptDonation) {
                    projectIds[j] = projectList[i].projectId;
                    minimumAmounts[j] = projectList[i].minimumAmount;
                    goals[j] = projectList[i].goal;
                    raisedAmounts[j] = projectList[i].raisedAmount;
                    j++;
                }
            }
            
            require(projectIds.length > 0,"No projects available for accepting donations");

            return (projectIds, minimumAmounts, goals, raisedAmounts);

    }

    // Donor will call this function
    function donate(uint charityId, uint projectId, uint donorId, uint amount) public payable {
            bool projectExist = false;
            Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId) { 
                    if (projectList[i].acceptDonation) {
                        
                        require(amount >= projectList[i].minimumAmount, "Should be greater than or equal to minimum amount");
                        
                        require(amount + projectList[i].raisedAmount <= projectList[i].goal, "Your contribution exceeds required amount.");

                        projectList[i].raisedAmount = projectList[i].raisedAmount + amount;

                        Donor[] storage allDonors = projectDonors[projectId];
                        uint idx = allDonors.length;
                        bool donorExist;

                        for (uint j=0;j<allDonors.length;j++) {
                            // If the donor and message sender are same, the amount should be added with  
                            // existing amount under the specific project
                             if (allDonors[j].owner == msg.sender) {
                                allDonors[j].projectwiseContributions[projectId] += amount;
                                donorExist = true;
                                break;
                            }
                        }

                        if (!donorExist) {   
                            // It means no donor already exist for this project
                
                            // let's create a new donor

                            allDonors.push();

                            Donor storage newDonor = allDonors[idx];
                            newDonor.donorId = donorId;
                            newDonor.owner = msg.sender;
                            newDonor.projectwiseContributions[projectId] = amount;
                        }

                        // If the project goal is reached
                        if (projectList[i].raisedAmount == projectList[i].goal) {
                            
                            // Change the status
                            projectList[i].projectStatus = ProjectStatus.PGA;

                            // No more donations accepted
                            projectList[i].acceptDonation = false;

                            // Notify the project status to the receiver. 
                            emit ReceiverMessageToCharity(charityId, projectId, ProjectStatus.PGA);
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

    // Donor will call this function
    function getRefund(uint charityId, uint projectId) public {
        bool projectExist = false;
        bool donorExist = false;
        Project[] storage projectList = charityProjects[charityId];
        require(projectList.length > 0,"Charity not found");

        Donor[] storage allDonors = projectDonors[projectId];

        for (uint j=0;j<allDonors.length;j++) {
            // If the donor and message sender are same and has given some contribution to this project
            if (allDonors[j].owner == msg.sender && allDonors[j].projectwiseContributions[projectId] > 0) {
                for (uint i=0;i<projectList.length;i++) {
                    if (projectList[i].projectId == projectId) { 
                        if (projectList[i].projectStatus > ProjectStatus.PGA) {
                            revert("Can't refund as exchange request was already initiated with board");
                        } else {
                            projectList[i].raisedAmount = projectList[i].raisedAmount - allDonors[j].projectwiseContributions[projectId];
                            
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

                payable (msg.sender).transfer(allDonors[j].projectwiseContributions[projectId]);
                allDonors[j].projectwiseContributions[projectId] = 0;

                donorExist = true;
                break;
            }
        }

        if (!donorExist)
            revert("You haven't contributed for this project");
    }

    // Charity will call this function
    function refundToAllDonors(uint charityId, uint projectId) private {
        bool projectExist = false;
        Project[] storage projectList = charityProjects[charityId];
        require(projectList.length > 0,"Charity not found");
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].projectId == projectId) { 
                require(projectList[i].projectStatus == ProjectStatus.XRJ, "Can't refund as exchange request was not rejected by the board");
            
                Donor[] storage allDonors = projectDonors[projectId];

                for (uint j=0;j<allDonors.length;j++) {
                    uint contribution = allDonors[j].projectwiseContributions[projectId];
                    payable (allDonors[j].owner).transfer(contribution);
                }
                
                projectExist = true;
                break;
            }
        }

        if (!projectExist)
            revert("No project exist under this projectId");
    }

    // Charity will call this function
    function tranferToReceiver(uint charityId, uint projectId) private {
        bool projectExist = false;
        Project[] storage projectList = charityProjects[charityId];
        require(projectList.length > 0,"Charity not found");
        for (uint i=0;i<projectList.length;i++) {
            if (projectList[i].projectId == projectId) { 
                payable (projectList[i].owner).transfer(projectList[i].raisedAmount);
                projectExist = true;
                break;
            }
        }

        if (!projectExist)
            revert("No project exist under this projectId");
    }

    function getProjectStatus(uint charityId, uint projectId) external view returns (
        string memory) {
           Project[] storage projectList = charityProjects[charityId];
            require(projectList.length > 0,"Charity not found");
            for (uint i=0;i<projectList.length;i++) {
                if (projectList[i].projectId == projectId) {
                    return projectStatuses[projectList[i].projectStatus];
                } 
            }

            revert("No such project exist under this charity");
    }
}