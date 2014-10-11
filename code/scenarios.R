# Scenario-generation for cycling rates in 2050 - run after msim.R

# 1st stage: generate 'top down' scenarios of cycling rate to 2050
load("df2050.Rdata") # load basic data on growth
# DfT scenario
s1 <- seq(0.017, 0.017 * 1.793, length.out = 11) # the sequence to 2025 - CP
# s1 <- seq(0.017, 0.017 * 1.083, length.out = 11) # the sequence to 2025 - PQ
p.yr <- s1[2] - s1[1]
dftend <- p.yr * 35 + 0.017
sdft <- seq(0.017, dftend, length.out = 36) * 100
dft <- data.frame(Year = 2015:2050, Perc_stages = sdft, Scenario = "DfT")

# Slow start
k = 26
B = sdft[11]
r = 0.15
time = 0:25
lgrowth <- (B * k * exp(r * time)) / (k + B * (exp( r * time) - 1) )
slow_start <- dft
slow_start$Scenario <- "Slow start"
slow_start$Perc_stages[11:36] <- lgrowth
# plot(slow_start$Year, slow_start$Perc_stages)

# Go Dutch scenario
k = 27
B = 1.7
r = 0.15
time = 0:35
lgrowth <- (B * k * exp(r * time)) / (k + B * (exp( r * time) - 1) )
go_dutch <- dft
go_dutch$Scenario <- "Go Dutch"
go_dutch$Perc_stages <- lgrowth
# plot(go_dutch$Year, go_dutch$Perc_stages)

ecotech <- go_dutch
ecotech$Scenario <- "Ecotechnic"

s2050 <- rbind(dft, slow_start, go_dutch, ecotech)
library(ggplot2)
ggplot() + geom_vline(xintercept = c(2025, 2050), linetype = 3) + geom_hline(yintercept = c(10, 25), linetype = 2) + geom_line(data = s2050, aes(x = Year, y = Perc_stages, color = Scenario, linetype = Scenario)) + ylab("Percentage of trips by bicycle") +  theme_bw() + scale_color_brewer(type = "qual", palette = 6, name = "Model") + scale_shape_discrete(name = "Data", solid = F) + geom_text(aes(2020, py, label = ptext), size = 4) +
  scale_linetype_manual(values = c(1,1,1,2), guide = "none")
# write.csv(s2050, "scenarios.csv")
# ggsave("figures/stages.png")


# tsam <- ntstrips[sample(nrow(ntstrips), size = 500), ] # sample dataset to play with
tsam <- ntstrips # the full dataset
head(tsam)

tsam$mode <- as.character(tsam$mode)
tsam$mode[grep("Other|Tax|Moto|LT|Rail", tsam$mode)] <- "Other"
tsam$mode[grep("bus", tsam$mode)] <- "Bus"
tsam$mode <- factor(tsam$mode)
summary(tsam$mode) # great - this is the data in the form it needs to be in...

tsam$purp <- as.character(tsam$purp)
tsam$purp[grep("Visit", tsam$purp)] <- "Visiting.friends"
library(knitr)
All_modes <- table(tsam$purp)

# Checking it works
library(ggplot2)
ggplot(tsam[ tsam$dist < 300, ]) + geom_histogram(aes(x = dist/10, fill = mode)) + scale_fill_brewer(type = "qual") + xlab("Miles")

library(birk) # package for distance conversion
tsam$dkm <- conv_unit(tsam$dist / 10, mi, km)

# Generate new mode column
iac <- function(x, a, b){
  a * exp(1)^(-b * x)
}
# plot(iac(1:10, 0.4, 0.3)) # test it makes sense
pswitch <- iac(tsam$dkm, a = 0.3, b = 0.2)
pswitch[ tsam$mode == "Bicycle"] <- 0 # probability of switch for cyclists = 0
# plot(pswitch, tsam$dkm)
set.seed(100)
size = length(which(tsam$mode == "Bicycle")) # the number of people who will switch mode

# Change in the cycling rate
# Rate of cycling in future - DfT scenario - baseline
size2025dft <- nrow(tsam) * s2050$Perc_stages[s2050$Scenario == "DfT" & s2050$Year == 2025] / 100 -
  nrow(tsam) * 0.017 #

# The go Dutch scenario
size2025godutch =  nrow(tsam) * s2050$Perc_stages[s2050$Scenario == "Go Dutch" & s2050$Year == 2025] / 100 -
  nrow(tsam) * 0.017

sel <- sample(nrow(tsam), size = size2025dft, prob = pswitch)
tsam$dswitch_2025_dft <- tsam$mode
tsam$dswitch_2025_dft[sel] <- "Bicycle"

sel <- sample(nrow(tsam), size = size2025godutch, prob = pswitch)
tsam$dswitch_2025_go <- tsam$mode
tsam$dswitch_2025_go[sel] <- "Bicycle"

# Savings / changes

# Baseline distance cycled
tsam$dcycle <- 0
tsam$dcycle[ tsam$mode == "Bicycle"] <- tsam$dkm[tsam$mode == "Bicycle"]

# Health benefits from increased cycling
tsam$dcycle_2025_dft <- tsam$dist * 0
tsam$dcycle_2025_dft[ tsam$dswitch_2025_dft == "Bicycle"] <- tsam$dkm[tsam$dswitch_2025_dft == "Bicycle"]

tsam$dcycle_2025_go <- tsam$dist * 0
tsam$dcycle_2025_go[ tsam$dswitch_2025_go == "Bicycle"] <- tsam$dkm[ tsam$dswitch_2025_go == "Bicycle"]

summary(tsam[c("dcycle_2025_go", "dcycle_2025_dft", "dcycle")])
names(tsam)
# Increase from current
# tsam$dcycleNew[sel] <- tsam$dkm[sel]
# tsam$dcycleNew[tsam$mode == "Walk"] <- 0

# Increase from future baseline
# future_shift

# Estimates of energy savings
tsam$epkm <- 0
tsam$epkm[ grep("driv", tsam$mode)  ] <- 3
tsam$epkm[ grep("Bus", tsam$mode)  ] <- 2

tsam$esave <- tsam$epkm * tsam$dkm

# Next stage: take tsam as input into msim to estimate savings per x
# The saving per person
indscen <- summarise(group_by(tsam, psuid, i1, house, yr), esave = sum(esave),
  dcycle = sum(dcycle), n = n())
summary(indscen)
summary(indscen$dcycle)
summary(indscen$dcycle[ indscen$dcycle > 0])
indscen <- inner_join(ind, indscen) # join other attributes to individ. data
summary(indscen)

summarise(group_by(tsam, region), esave = sum(esave, na.rm = T)) # saving per zone