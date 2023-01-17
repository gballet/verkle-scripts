disp("loading account data")
accounts = load('accounts.dat');
disp("loading storage data")
storage = load('storage.dat');
pkg load statistics;
boxplot({accounts, storage});
axis([0 3 -1 15])
set(gca,'XTickLabel',{'Accounts' , 'Storage'});
set(gca,'XTick',[1,2]);
title(sprintf("Depths of account and storage accesses in the 16232207 - 16425258 block range"))
ylabel('Depth (# nodes)')
print -dpng depths.png