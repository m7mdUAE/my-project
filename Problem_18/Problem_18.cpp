#include <iostream>
#include<string>
using namespace std;

string Readpassword(string message) {

	string password;

	cout << message<<endl;
	getline(cin, password);


	while (password.length() < 6) {
		cout << "Your password should be at least 5 letters : \n";
		getline(cin, password);

	}

	return password;
}

string Encryption(string &password) {

	string encryptionvalue = "";
	for (char x = 0;x < password.length();x++) {


		encryptionvalue += password[x] + 2;
	}
	return encryptionvalue;
}



int main()
{

	string password = Readpassword("Please enter the password : \n");
	cout << "Your password after encryption is : " << Encryption(password) << endl;;

	cout << "Your orignial password is : " << password;

		}
		


	



