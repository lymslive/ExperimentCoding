create table staff(
	StaffID int auto_increment primary key,
	FirstName varchar(15) not null,
	LastName varchar(15) not null,
	Address varchar(30),
	City varchar(15),
	State varchar(3),
	Position varchar(20) not null,
	Wage int not null
);

create table projects(
	StaffID int not null,
	ProjectName varchar(20) not null,
	Allocation int not null,
	primary key (StaffID, ProjectName),
	foreign key (StaffID) references staff(StaffID) on delete cascade
);

create table staffphone(
	StaffID int not null,
	PhoneNumber varchar(15) not null,
	primary key (StaffID, PhoneNumber),
	foreign key (StaffID) references staff(StaffID) on delete cascade
);
