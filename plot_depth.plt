set terminal png
set output 'boxplot2.png'
set boxwidth 0.5
set style data boxplot
set style fill solid 0.5
set title "Depths of account and storage reads in the 16,232,207-16,425,258 block range" center
plot 'account_depths.dat' using (1):1 with boxes title 'Accounts', \
     'storage_depths.dat' using (2):2 with boxes title 'Storage slots'
