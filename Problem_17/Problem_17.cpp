#include<iostream>
#include< string>
using namespace std;

string user_Input(string message) {
    string pass = "";

    cout << message << endl;
    getline(cin, pass);

    while (pass.length() != 3) {

        cout << "Password should be 3 letters only : \n";
        getline(cin, pass);


    }



    return pass;
}

int main() {
    string password = user_Input("Please enter your password ( 3 letters only) ");
    bool validation = false;
    int trail = 1;
    for (char x = 65; x < 91; x++)
    {
        for (char y = 65; y < 91; y++)
        {
            for (char z = 65; z < 91; z++)
            {
                string counter = "";
                counter += x;
                counter += y;
                counter += z;


                if (password != counter) {


                    trail++;
                    continue;
                }
                else {
                    cout << "Your password is " << password << endl;
                    cout << "Found after " << trail << " trails";
                    validation = true;
                    break;
                }

            }

            }
        if (validation) {
            break;
    }
    
    }
    if (validation == false) {

        cout << "Cannot find your password, maybe you entered a lowercase password";
    }

    cout << endl;
    cout << "Thank you for using my program ";

    }










