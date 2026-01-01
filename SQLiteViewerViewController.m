#import "SQLiteViewerViewController.h"
#import <sqlite3.h>
#import "Typography.h"

@interface SQLiteViewerViewController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *tableNames;
@property (nonatomic, strong) NSArray *currentTableData;
@property (nonatomic, strong) NSArray *currentColumnNames;
@property (nonatomic, assign) sqlite3 *database;

@end

@implementation SQLiteViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = [self.dbPath lastPathComponent];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cerrar", nil) style:UIBarButtonItemStylePlain target:self action:@selector(closeViewer)];

    // Initialize table view
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    [self openDatabase];
}

- (void)closeViewer {
    if (self.database) {
        sqlite3_close(self.database);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openDatabase {
    if (sqlite3_open([self.dbPath UTF8String], &_database) != SQLITE_OK) {
        [self showError:@"No se pudo abrir la base de datos"];
        return;
    }

    [self loadTableNames];
}

- (void)loadTableNames {
    const char *query = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';";
    sqlite3_stmt *statement;

    NSMutableArray *tables = [NSMutableArray array];

    if (sqlite3_prepare_v2(self.database, query, -1, &statement, NULL) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            const char *tableName = (const char *)sqlite3_column_text(statement, 0);
            [tables addObject:[NSString stringWithUTF8String:tableName]];
        }
        sqlite3_finalize(statement);
    }

    self.tableNames = tables;
    [self.tableView reloadData];
}

- (void)loadTableData:(NSString *)tableName {
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ LIMIT 100;", tableName];
    sqlite3_stmt *statement;

    NSMutableArray *rows = [NSMutableArray array];
    NSMutableArray *columns = [NSMutableArray array];

    if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK) {
        // Get column names
        int columnCount = sqlite3_column_count(statement);
        for (int i = 0; i < columnCount; i++) {
            const char *columnName = sqlite3_column_name(statement, i);
            [columns addObject:[NSString stringWithUTF8String:columnName]];
        }

        // Get rows
        while (sqlite3_step(statement) == SQLITE_ROW) {
            NSMutableArray *row = [NSMutableArray array];
            for (int i = 0; i < columnCount; i++) {
                const char *value = (const char *)sqlite3_column_text(statement, i);
                NSString *stringValue = value ? [NSString stringWithUTF8String:value] : @"NULL";
                [row addObject:stringValue];
            }
            [rows addObject:row];
        }
        sqlite3_finalize(statement);
    }

    self.currentTableData = rows;
    self.currentColumnNames = columns;
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.currentTableData ? 1 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.currentTableData) {
        return self.currentTableData.count;
    } else {
        return self.tableNames.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"SQLiteCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    if (self.currentTableData) {
        // Showing table data
        NSArray *row = self.currentTableData[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"Row %ld", (long)indexPath.row + 1];
        cell.textLabel.font = [Typography bodyMedium];
        cell.detailTextLabel.text = [row componentsJoinedByString:@" | "];
        cell.detailTextLabel.font = [Typography bodySmall];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        // Showing table names
        cell.textLabel.text = self.tableNames[indexPath.row];
        cell.textLabel.font = [Typography bodyMedium];
        cell.detailTextLabel.text = @"Tabla";
        cell.detailTextLabel.font = [Typography labelSmall];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.currentTableData) {
        return [NSString stringWithFormat:@"Datos de la tabla (%lu filas)", (unsigned long)self.currentTableData.count];
    } else {
        return [NSString stringWithFormat:@"Tablas (%lu)", (unsigned long)self.tableNames.count];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.currentTableData) {
        // Selected a table, load its data
        NSString *tableName = self.tableNames[indexPath.row];
        [self loadTableData:tableName];
        [self.tableView reloadData];

        // Add back button
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Atrás", nil) style:UIBarButtonItemStylePlain target:self action:@selector(goBackToTables)];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)goBackToTables {
    self.currentTableData = nil;
    self.currentColumnNames = nil;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cerrar", nil) style:UIBarButtonItemStylePlain target:self action:@selector(closeViewer)];
    [self.tableView reloadData];
}

@end
