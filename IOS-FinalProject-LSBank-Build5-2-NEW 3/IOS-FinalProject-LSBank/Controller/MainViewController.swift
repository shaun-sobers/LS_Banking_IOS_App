//
//  MainViewController.swift
//  IOS-FinalProject-LSBank
//
//  Created by user203175 on 10/19/21.
//

import UIKit

class MainViewController: UIViewController, BalanceRefresh, UITableViewDelegate, UITableViewDataSource {
    var context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var recentTransactions : [TransactionsStatementTransaction] = []
    @IBOutlet weak var vBtnWithdraw : UIView!
    @IBOutlet weak var vBtnDeposit : UIView!
    @IBOutlet weak var vBtnTransfer : UIView!
    
    @IBOutlet weak var lblUsername : UILabel!
    @IBOutlet weak var lblBalance : UILabel!
    
    var refreshControl = UIRefreshControl()
    
    @IBOutlet weak var lblTransaction: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var btnRefreshBalance : UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        initialize()
        
        lblUsername.text = "Hi \(LoginViewController.account!.firstName)"
        
        refreshBalance()

        
    }
    
    private func initialize(){
        customizeView()
        
       
        
        //connection for table view
        tableView.register(TransactionTableViewCell.nib(), forCellReuseIdentifier: TransactionTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        refreshControl.addTarget(self, action: #selector(tableRefreshControl), for: UIControl.Event.valueChanged)
     
        tableView.addSubview(refreshControl)
    }
    
    @objc func tableRefreshControl(send : UIRefreshControl) {
        
        let now = Date()
        DispatchQueue.main.async {

            print("Refreshed on \(now)")
            self.refreshBalance()
            self.refreshRecentTransactions()
            self.refreshControl.endRefreshing()
        }
        
    }
    
    
    
    private func customizeView() {
        vBtnWithdraw.setLayerCornerRadius(MyAppDefaults.LayerCornerRadius.button)
        vBtnDeposit.setLayerCornerRadius(MyAppDefaults.LayerCornerRadius.button)
        vBtnTransfer.setLayerCornerRadius(MyAppDefaults.LayerCornerRadius.button)
    }
    
    
    @IBAction func btnLogOff(_ sender: Any) {
        
        let btnYes = Dialog.DialogButton(title: "Yes", style: .default, handler: {action in
            self.navigationController?.popViewController(animated: true)
        })
        let btnNo = Dialog.DialogButton(title: "No", style: .destructive, handler: nil)
        
        Dialog.show(view: self, title: "Login off", message: "\(LoginViewController.account!.firstName), are you sure you want to leave?", style: .actionSheet, completion: nil, presentAnimated: true, buttons: btnYes, btnNo)
        
        
    }
    
    
    
    func refreshBalanceSuccess(httpStatusCode : Int, response : [String:Any] ){
        
        DispatchQueue.main.async {
            self.btnRefreshBalance.isEnabled = true
            self.lblBalance.text = "?"
        }
        
        if httpStatusCode == 200 {
            
            if let accountBalance = AccountsBalance.decode(json: response){
                
                DispatchQueue.main.async {
                    self.lblBalance.text = "CAD$ " + accountBalance.balance.formatAsCurrency()
                }
                
            }
        } else {
            DispatchQueue.main.async {
                Toast.show(view: self, title: "Something went wrong!", message: "Error parsing data received from server! Try again!")
            }
        }
        
    }
    
    
    func refreshBalanceFail( httpStatusCode : Int, message : String ){
        
        DispatchQueue.main.async {
            self.lblBalance.text = ""
            self.btnRefreshBalance.isEnabled = true
            Toast.show(view: self, title: "Ooops!", message: message)
        }
        
    }
    
    
    
    func refreshBalance() {
        
        lblBalance.text = "wait..."
        
        LSBankAPI.accountBalance(token: LoginViewController.token, successHandler: refreshBalanceSuccess, failHandler: refreshBalanceFail)
        refreshRecentTransactions()
    }
    
    //call api and get information
    func refreshRecentTransactions(){
        LSBankAPI.statement(token: LoginViewController.token, days: 30, successHandler: refreshRecentTransactionsSuccess, failHandler: refreshRecentTransactionsFail)
        
    }
    
    func refreshRecentTransactionsSuccess(httpStatusCode : Int, response : [String:Any] ){
        
        DispatchQueue.main.async {
            
        }
        
        
        if httpStatusCode == 200 {
            
            if let transactions = TransactionStatement.decode(json: response){
                
                DispatchQueue.main.async {
                    self.recentTransactions = transactions.statement
                    self.tableView.reloadData()
                }
                
            }
        } else {
            DispatchQueue.main.async {
                Toast.show(view: self, title: "Something went wrong!", message: "Error parsing data received from server! Try again!")
            }
        }
        
    }
    
    
    func refreshRecentTransactionsFail( httpStatusCode : Int, message : String ){
        
        DispatchQueue.main.async {
            Toast.show(view: self, title: "Ooops!", message: message)
        }
        
    }
    
    @IBAction func btnRefreshBalanceTouchUp(_ sender : Any? ) {
        
        btnRefreshBalance.isEnabled = false
        refreshBalance()
        
    }
    
    @IBAction func btnPayeeTouchUp(_ sender : Any? ) {
        
        performSegue(withIdentifier: Segue.toPayeesView, sender: nil)
        
    }
    
    @IBAction func btnSendMoneyTouchUp(_ sender : Any? ){
        
        if Payee.all(context: self.context).count == 0 {
            Toast.ok(view: self, title: "No payees", message: "Please, set your payees list before sending money!")
            return
        }
        
        
        performSegue(withIdentifier: Segue.toSendMoneyView, sender: nil)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == Segue.toSendMoneyView {
            
            (segue.destination as! SendMoneyViewController).payeeList = Payee.allByFirstName(context: self.context)
            (segue.destination as! SendMoneyViewController).delegate = self
            
            
        }
        
    }
    
    func balanceRefresh() {
        // BalanceRefresh protocol stub
        self.refreshBalance()
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.recentTransactions.count
        
    }
    
    
    //this code is called 10 times, because we returned 10
    //This function fills the cells row by row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: TransactionTableViewCell.identifier, for: indexPath) as!
            TransactionTableViewCell
        
        let transaction = self.recentTransactions[self.recentTransactions.count - 1 - indexPath.row]
        
        var accountHolderName: String = ""
        var credit : Bool = false
        
        //define if the transaction is debit or credit
        if transaction.fromAccount!.accountId.contains(LoginViewController.account!.accountId){
            credit = false //debit
            accountHolderName =
                "\(transaction.toAccount!.firstName.uppercased()) \(transaction.toAccount!.lastName.uppercased())"
            
        }else{
            credit = true
            accountHolderName =
                "\(transaction.fromAccount!.firstName.uppercased()) \(transaction.fromAccount!.lastName.uppercased())"
        }
        
        cell.setCellContent(dateTime: transaction.dateTime, accountHolder: accountHolderName, message: transaction.message, amount: transaction.amount, credit: credit)
        
        if recentTransactions.count == 0 {
            lblTransaction.text = "No recent transactions"
        }
        if recentTransactions.count == 1 {
            lblTransaction.text = "1 Recent tranction"
        } else
        {
            lblTransaction.text = "\(recentTransactions.count) Recent transactions"
        }
        
        return cell
        
       
    }
    
    //to set the height of the rows
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let transaction = self.recentTransactions[indexPath.row]
        
        if transaction.message.count == 0 {
            return 90
            
        }else{
            return 120
            
        }
    }
    
}
