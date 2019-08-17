#!perl
##############################################################################
#                            Настройки                                       #
##############################################################################
use strict;
use warnings;
use dbi; # модуль для работы с ms-sql

my $parsing_file_name = 'card_history.log';
my $current_cardnumber = '';
my $last_card = '';
my $last_price = 0;

#operation type
#Пополнение счета = 1
#Выдача карты = 2
#Возврат карты = 4
#Возврат карты и денег = 5
my $operation_type = 0;

#Настройки для подключения к базе
#my $base = 'TEST';
#my $user = 'sa';
#my $pass = '---';
#my $host = '---';
#my $dbh = DBI->connect("DBI:ODBC:driver={SQL Server};Server=$host;database=$base", $user, $pass) or die "Error connected to Sql Server $!\n";
###############################################################################


#!!!!Тело программы!!!!#
&parsing();
$dbh->disconnect();

##############################################################################
#                            Функии                                          #
##############################################################################
sub parsing 
{
open READ_LOG_FILE, "<", $parsing_file_name or die "Error open file $parsing_file_name -> $!\n";


while (<READ_LOG_FILE>) 
{

chomp;
 
 $last_card = $current_cardnumber if (/CloseCheque/);
 
 if (/\d+=\d+=(\d+)/) 
 {
 $last_card = '$last_card';
 next if ($current_cardnumber eq $1);
 $current_cardnumber = $1;
 }

# next if ($current_cardnumber ne '');
 
 if (/(Пополнение счета|Выдача карты|Возврат средств)/)
{
 if ($1 eq 'Пополнение счета') {$operation_type = 1;$last_card = '';next;}
 if ($1 eq 'Выдача карты') {$operation_type = 2;$last_card = '';next;}
 if ($1 eq 'Возврат средств') 
 {
	#определяем какой возврат
	$operation_type = 4 if ($current_cardnumber ne $last_card);
	$operation_type = 5 if ($current_cardnumber eq $last_card);
 }
}

 if (/(\d{2,2})(\d{2,2})(\d{2,2}) (\d{2,2}):(\d{2,2}):(\d{2,2}).*Payment\((\d+).*#(\d)\)/)
{
 my $year = $1 + 2000;
 my $date = "$year-$2-$3 $4:$5:$6";
 if ($operation_type == 5)
 {
 returnBalance($current_cardnumber,$last_price,$date);
 &cardReturn($current_cardnumber,$7,$date);
 #print "change $current_cardnumber $last_price 0 $operation_type\n";
 #print "$date $current_cardnumber $last_price 0 3\n";
 #print "$date $current_cardnumber $7 $8 4\n";
 next;
 }
 &cardReturn($current_cardnumber,$7,$date) if ($operation_type == 4);
 &createCard($current_cardnumber,$7,$date,$8) if ($operation_type == 2);
 &addPay($current_cardnumber,$7,$date,$8) if ($operation_type == 1);
 #print "$date $current_cardnumber $7 $8 $operation_type\n";
 $last_price = $7;
}
 
} #end while read_log_file

close READ_LOG_FILE;
}
 
sub returnBalance
{
my ($card,$pay,$date) = @_;
}
 
sub cardReturn
{
my ($card,$pay,$date) = @_;
my $sth = $dbh->prepare("SELECT id FROM LoyaltyCard WHERE CardNumber = $card") or die "Error prepare sql $!";
$sth->execute()  or die $DBI::errstr;
	while((my $id) = $sth->fetchrow())
	{
	my $sth2 = $dbh->prepare("UPDATE LoyaltyCard SET IssueDate = NULL  WHERE CardNumber = $card") or die "Error prepare sql $!";   
	$sth2->execute()  or die $DBI::errstr;
	my $sth3 = $dbh->prepare("INSERT INTO CardAccountOperation (ID,LoyaltyCardID,CardAccountOperationTypeID,ShiftID,Amount,OperationDate)
	VALUES((SELECT ISNULL(MAX(id) + 1, 0) FROM CardAccountOperation),?,?,?,?,?)") or die "Error prepare sql $!";    
	$sth3->execute($id,'12','313840688',$pay,$data)  or die $DBI::errstr;
	}
$sth->finish();
}
 
sub addPay
{
my ($card,$pay,$date,$type_pay) = @_;
my $sth = $dbh->prepare("SELECT id FROM LoyaltyCard WHERE CardNumber = $card") or die "Error prepare sql $!";
$sth->execute()  or die $DBI::errstr;
	while((my $id) = $sth->fetchrow())
	{
	my $sth2 = $dbh->prepare("INSERT INTO CardAccountOperation (ID,LoyaltyCardID,CardAccountOperationTypeID,ShiftID,Amount,OperationDate,PaymentTypeID)
	VALUES((SELECT ISNULL(MAX(id) + 1, 0) FROM CardAccountOperation),?,?,?,?,?,?)") or die "Error prepare sql $!";    
	$sth2->execute($id,'1','313840688',$pay,$date,$type_pay < 2 ? 1 : 2)  or die $DBI::errstr;
	}
$sth->finish();
}
 
sub createCard 
{
my ($card,$pay,$date,$type_pay) = @_;
my $sth = $dbh->prepare("SELECT id FROM LoyaltyCard WHERE CardNumber = $card") or die "Error prepare sql $!";
$sth->execute()  or die $DBI::errstr;
	while((my $id) = $sth->fetchrow())
	{
	my $sth2 = $dbh->prepare("UPDATE LoyaltyCard SET IssueDate = '$date' WHERE CardNumber = $card") or die "Error prepare sql $!";   
	$sth2->execute()  or die $DBI::errstr;
	my $sth3 = $dbh->prepare("INSERT INTO CardAccountOperation (ID,LoyaltyCardID,CardAccountOperationTypeID,ShiftID,Amount,OperationDate,PaymentTypeID) 
	VALUES((SELECT ISNULL(MAX(id) + 1, 0) FROM CardAccountOperation),?,?,?,?,?,?)") or die "Error prepare sql $!";    
	$sth3->execute($id,'11','313840688',$pay,$date,$type_pay)  or die $DBI::errstr;
	}
$sth->finish();
}

#Функция получает текущаю дату
sub current_date {
my ($sec,$min,$hour,$day,$month,$year) = localtime(time());
$month++;$year +=1900;
my $date = sprintf "%02d-%02d-%02d %02d-%02d-%4d" , $hour , $min , $sec , $day , $month , $year;
return $date;
}