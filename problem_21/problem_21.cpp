#include <iostream>
#include <cstdlib>
#include <ctime>
using namespace std;


int User_Input()
{
	int num = 0;
	
	do {

		cout << "Enter a positive number: ";
		cin >> num;

	} while (num <= 0);


	return num;
}

int RandomNumber(int From, int To)
{

	int randNum = rand() % (To - From + 1) + From;

	return randNum;
}

string randomletters() {
	string final_letters = "";

	short i = 0;
	while (i < 4) {

		char x =(RandomNumber(65, 90));

		final_letters += x;
		i++;
	}
	return final_letters;

}










int main()
{
	srand((unsigned)time(NULL));

	int num = User_Input();
	cout << endl;
	cout << " Here are the keys : \n";

	for (int i = 0; i < num; i++) {
		cout << "Key [" << i + 1 << "] : " << randomletters() << "-"<< randomletters() << "-" << randomletters() << "-" << randomletters() << endl;



	}

    return 0;
}